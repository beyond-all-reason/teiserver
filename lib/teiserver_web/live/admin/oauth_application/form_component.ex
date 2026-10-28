defmodule TeiserverWeb.AdminLive.OAuthApplication.FormComponent do
  @moduledoc false
  alias Teiserver.Account.Scope
  alias Teiserver.Logging.AuditLog
  alias Teiserver.OAuth
  alias Teiserver.OAuth.Application

  use TeiserverWeb, :live_component

  attr :title, :string, required: true
  attr :action, :string, required: true
  attr :oauth_application, Application, required: true
  attr :patch, :string, required: true
  attr :scope, Scope, required: true

  @impl LiveComponent
  def render(assigns) do
    scopes =
      OAuth.allowed_scopes()
      |> Enum.map(fn scope -> {scope, OAuth.scope_description(scope)} end)

    assigns =
      assigns
      |> assign(
        changed?: not Enum.empty?(assigns.form.source.changes),
        allowed_scopes: scopes
      )

    ~H"""
    <div>
      <.header>
        {@title}
      </.header>

      <.simple_form
        for={@form}
        id="oauth_application-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input_tw field={@form[:name]} type="text" label="Name (User facing)" />
        <.input_tw field={@form[:uid]} type="text" label="Client ID" />

        <.input_tw
          field={@form[:scopes]}
          type="checkbox-array"
          options={@allowed_scopes}
          label="Scopes"
        />

        <.live_component
          module={TeiserverWeb.LiveComponents.UserPicker}
          id="owner-picker"
          field={@form[:owner_id]}
          label="Owner"
        />

        <.input_tw
          field={@form[:redirect_uris]}
          type="textarea-array"
          label="Redirect urls, one per line"
        />

        <.input_tw
          :if={@action == :new}
          field={@form[:confidential?]}
          type="checkbox"
          label="Confidential client? (When checked, a secret will be generated for the app )"
        />

        <.input_tw field={@form[:description]} type="text" label="Short description" />

        <:actions>
          <div class="flex">
            <.button
              phx-disable-with="Saving..."
              class={["float-right btn btn-primary", not @changed? && "btn-soft"]}
            >
              Save OAuth application
            </.button>
          </div>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl LiveComponent
  def update(%{oauth_application: oauth_application} = assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_new(:form, fn ->
      to_form(OAuth.change_application(oauth_application))
    end)
    |> ok()
  end

  @impl LiveComponent
  def handle_event("validate", %{"application" => oauth_application_params}, socket) do
    oauth_application_params =
      oauth_application_params
      |> split_redirects()

    changeset =
      OAuth.change_application(socket.assigns.oauth_application, oauth_application_params)

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"application" => oauth_application_params}, socket) do
    oauth_application_params =
      oauth_application_params
      |> split_redirects()

    save_oauth_application(socket, socket.assigns.action, oauth_application_params)
  end

  defp save_oauth_application(socket, :edit, oauth_application_params) do
    %{oauth_application: oauth_application, scope: scope, patch: patch} = socket.assigns

    changeset = OAuth.change_application(oauth_application, oauth_application_params)

    result =
      Repo.transact(fn ->
        with true <- allow?(scope, "Admin"),
             {:ok, updated_oauth_application} <- Repo.update(changeset),
             %AuditLog{} <-
               add_audit_log(scope, "Update Application", %{
                 oauth_application_id: oauth_application.id,
                 changes: changeset.changes
               }) do
          {:ok, updated_oauth_application}
        end
      end)

    case result do
      {:ok, updated_oauth_application} ->
        notify_parent({:saved, updated_oauth_application})

        socket
        |> put_flash(:info, "OAuth application updated successfully")
        |> push_patch(to: patch)
        |> noreply()

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_oauth_application(socket, :new, oauth_application_params) do
    %{scope: scope} = socket.assigns

    result =
      Repo.transact(fn ->
        with true <- allow?(scope, "Admin"),
             {:ok, oauth_application} <-
               OAuth.create_application(oauth_application_params),
             %AuditLog{} <-
               add_audit_log(scope, "Create Application", %{
                 oauth_application_id: oauth_application.id,
                 params: oauth_application_params
               }) do
          {:ok, oauth_application}
        end
      end)

    case result do
      {:ok, oauth_application} ->
        notify_parent({:saved, oauth_application})

        key = make_secret_key()
        Teiserver.cache_put(:secrets, key, oauth_application.plain_text_secret)

        socket
        |> put_flash(:info, "OAuth application created successfully")
        |> push_navigate(to: ~p"/admin/oauth_applications/#{oauth_application.id}/show/#{key}")
        |> noreply()

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp split_redirects(%{"redirect_uris" => redirects_raw} = params) do
    redirects =
      redirects_raw
      |> String.split("\n", trim: true)
      |> Enum.map(&String.trim/1)

    Map.put(params, "redirect_uris", redirects)
  end

  defp split_redirects(params), do: params

  defp make_secret_key do
    :crypto.strong_rand_bytes(16) |> Base.hex_encode32(padding: false)
  end
end
