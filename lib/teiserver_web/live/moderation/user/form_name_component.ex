defmodule TeiserverWeb.ModerationLive.User.FormNameComponent do
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
    # User stat might be nil or the data may not have a previous_names entry
    previous_names =
      case assigns[:user] do
        %{user_stat: nil} -> []
        %{user_stat: %{data: data}} -> Map.get(data, "previous_names", [])
      end

    assigns =
      assigns
      |> assign(
        changed?: not Enum.empty?(assigns.form.source.changes),
        previous_names: previous_names
      )

    ~H"""
    <div>
      <.header>
        User rename form
      </.header>

      <.simple_form
        for={@form}
        id="user-rename-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input_tw field={@form[:name]} type="text" label="New user name" autocomplete="off" />

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
            <div
              phx-click="random-name"
              phx-target={@myself}
              class="btn btn-info w-full"
            >
              Choose random name
            </div>
          </div>
          <div class="flex-1">
            <.button
              phx-disable-with="Saving..."
              class={["w-full btn btn-primary", not @changed? && "btn-soft"]}
            >
              Change name
            </.button>
          </div>
        </div>
      </.simple_form>

      <div :if={not Enum.empty?(@previous_names)} class="mt-8">
        <h3 class="text-xl font-bold">Previous names ({Enum.count(@previous_names)})</h3>
        <textarea name="" id="" rows="8" class="input w-full h-50">{Enum.join(@previous_names, "\n")}</textarea>
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
  def handle_event("random-name", _params, socket) do
    random_name = "renamed#{:rand.uniform(899_999_999) + 100_000_000}"

    socket
    |> assign(form: to_form(Account.change_user(socket.assigns.user, %{name: random_name})))
    |> noreply()
  end

  def handle_event("validate", %{"user" => %{"name" => new_name}}, socket) do
    changeset = User.rename_changeset(socket.assigns.user, new_name)

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"user" => %{"name" => new_name}}, socket) do
    %{user: %User{} = user, scope: scope} = socket.assigns
    admin_action = allow?(scope, "Senior moderator")

    result =
      Repo.transact(fn ->
        with true <- allow?(scope, "Moderator"),
             %{valid?: true} <- User.rename_changeset(socket.assigns.user, new_name),
             :success <- Account.rename_user(user.id, new_name, admin_action),
             %{} <-
               add_audit_log(scope, "Changed user name", %{
                 user_id: user.id,
                 old_name: user.name,
                 new_name: new_name
               }) do
          {:ok, %User{user | name: new_name}}
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
        |> put_flash(:info, "User renamed successfully")
        |> push_patch(to: ~p"/moderation/users/#{user.id}")
        |> noreply()

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
