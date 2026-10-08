defmodule TeiserverWeb.ModerationLive.User.FormEmailComponent do
  @moduledoc false
  alias Teiserver.Account
  alias Teiserver.Account.Scope
  alias Teiserver.Account.User

  use TeiserverWeb, :live_component

  attr :action, :string, required: true
  attr :user, User, required: true
  attr :scope, Scope, required: true

  @impl LiveComponent
  def render(assigns) do
    assigns =
      assigns
      |> assign(changed?: not Enum.empty?(assigns.form.source.changes))

    ~H"""
    <div>
      <.header>
        User email change form
      </.header>

      <.simple_form
        for={@form}
        id="user-email_change-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input_tw field={@form[:email]} type="email" label="New user email" autocomplete="off" />

        <div class="flex space-x-2 mt-2">
          <div class="flex-1">
            <.link
              patch={~p"/moderation/users/#{@user.id}"}
              class="btn btn-neutral btn-soft w-full"
            >
              Cancel
            </.link>
          </div>
          <div class="flex-1">
            <.button
              phx-disable-with="Saving..."
              class={["w-full btn btn-primary", not @changed? && "btn-soft"]}
            >
              Change email
            </.button>
          </div>
        </div>
      </.simple_form>

      <div :if={not Enum.empty?(@user.previous_emails || [])} class="mt-8">
        <h3 class="text-xl font-bold">Previous emails ({Enum.count(@user.previous_emails)})</h3>
        <textarea email="" id="" rows="8" class="input w-full h-50">{Enum.join(@user.previous_emails, "\n")}</textarea>
      </div>
    </div>
    """
  end

  @impl LiveComponent
  def update(%{user: user} = assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_new(:form, fn ->
      to_form(Account.change_user(user))
    end)
    |> ok()
  end

  @impl LiveComponent
  def handle_event("validate", %{"user" => %{"email" => new_email}}, socket) do
    changeset = User.system_email_changeset(socket.assigns.user, new_email)

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"user" => %{"email" => new_email}}, socket) do
    %{user: %User{} = user, scope: scope} = socket.assigns

    result =
      Repo.transact(fn ->
        with true <- allow?(scope, "Senior moderator"),
             %Changeset{valid?: true} = changeset <-
               User.system_email_changeset(socket.assigns.user, new_email),
             {:ok, %User{} = updated_user} <- Repo.update(changeset),
             %{} <-
               add_audit_log(scope, "Changed user email", %{
                 user_id: user.id,
                 old_email: user.email,
                 new_email: new_email
               }) do
          Account.decache_user(user.id)
          {:ok, updated_user}
        else
          # We have a few things that don't return an error pair
          # this catches them for the transaction
          {:error, error} -> {:error, error}
          error -> {:error, error}
        end
      end)

    case result do
      {:ok, updated_user} ->
        notify_parent({:saved, updated_user})

        socket
        |> put_flash(:info, "User email changed successfully")
        |> push_patch(to: ~p"/moderation/users/#{user.id}")
        |> noreply()

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
