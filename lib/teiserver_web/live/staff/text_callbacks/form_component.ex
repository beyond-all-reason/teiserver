defmodule TeiserverWeb.StaffLive.TextCallback.FormComponent do
  @moduledoc false
  alias Teiserver.Account.Scope
  alias Teiserver.Communication
  alias Teiserver.Communication.TextCallback

  use TeiserverWeb, :live_component

  attr :title, :string, required: true
  attr :action, :string, required: true
  attr :text_callback, TextCallback, required: true
  attr :patch, :string, required: true
  attr :scope, Scope, required: true

  @impl LiveComponent
  def render(assigns) do
    assigns =
      assigns
      |> assign(changed?: not Enum.empty?(assigns.form.source.changes))

    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Use this form to manage text_callback records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="text_callback-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input_tw field={@form[:name]} type="text" label="Name" />

        <.input_tw field={@form[:enabled]} type="checkbox" label="Enabled?" />

        <.input_tw field={@form[:category]} type="text" label="Category" />

        <.input_tw field={@form[:response]} type="textarea" label="Response" />

        <:actions>
          <div class="flex">
            <.button
              phx-disable-with="Saving..."
              class={["float-right btn btn-primary", not @changed? && "btn-soft"]}
            >
              Save Text callback
            </.button>
          </div>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl LiveComponent
  def update(%{text_callback: text_callback} = assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_new(:form, fn ->
      to_form(Communication.change_text_callback(text_callback))
    end)
    |> ok()
  end

  @impl LiveComponent
  def handle_event("validate", %{"text_callback" => text_callback_params}, socket) do
    changeset =
      Communication.change_text_callback(socket.assigns.text_callback, text_callback_params)

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"text_callback" => text_callback_params}, socket) do
    save_text_callback(socket, socket.assigns.action, text_callback_params)
  end

  defp save_text_callback(socket, :edit, text_callback_params) do
    %{text_callback: text_callback, scope: scope, patch: patch} = socket.assigns
    changeset = Communication.change_text_callback(text_callback, text_callback_params)

    result =
      Repo.transact(fn ->
        with true <- allow?(scope, "Admin"),
             {:ok, updated_text_callback} <- Repo.update(changeset),
             %{} <-
               add_audit_log(scope, "Update TextCallback", %{
                 text_callback_id: text_callback.id,
                 changes: changeset.changes
               }) do
          {:ok, updated_text_callback}
        end
      end)

    case result do
      {:ok, updated_text_callback} ->
        notify_parent({:saved, updated_text_callback})

        socket
        |> put_flash(:info, "Text callback updated successfully")
        |> push_patch(to: patch)
        |> noreply()

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_text_callback(socket, :new, text_callback_params) do
    %{scope: scope, patch: patch} = socket.assigns

    result =
      Repo.transact(fn ->
        with true <- allow?(scope, "Admin"),
             {:ok, text_callback} <-
               Communication.create_text_callback(text_callback_params),
             %{} <-
               add_audit_log(scope, "Create TextCallback", %{
                 text_callback_id: text_callback.id,
                 params: text_callback_params
               }) do
          {:ok, text_callback}
        end
      end)

    case result do
      {:ok, text_callback} ->
        notify_parent({:saved, text_callback})

        socket
        |> put_flash(:info, "Text callback created successfully")
        |> push_patch(to: patch)
        |> noreply()

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
