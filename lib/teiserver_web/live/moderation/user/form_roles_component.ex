defmodule TeiserverWeb.ModerationLive.User.FormRolesComponent do
  @moduledoc false
  alias Ecto.Changeset
  alias Teiserver.Account.Role
  alias Teiserver.Account.RoleLib
  alias Teiserver.Account.Scope
  alias Teiserver.Account.User
  alias Teiserver.Account.UserLib

  use TeiserverWeb, :live_component

  attr :action, :string, required: true
  attr :user, User, required: true
  attr :scope, Scope, required: true
  attr :role_data, :list
  attr :has_active_mfa?, :boolean

  @role_groups [
    {:management, "Admin"},
    {:moderation, "Senior moderator"},
    {:staff, "Admin"},
    {:privileged, nil},
    {:common, nil},
    {:system, "Admin"},
    {:hidden, "Server"}
  ]

  @impl LiveComponent
  def render(assigns) do
    assigns =
      assigns
      |> assign(changed?: not Enum.empty?(assigns.form.source.changes))
      |> assign_new(:role_groups, fn -> @role_groups end)
      |> assign_new(:selected_roles, fn -> assigns.user.roles end)

    ~H"""
    <div>
      <.header>
        User roles change form
      </.header>

      <div :if={not @has_active_mfa?} class="alert alert-warning">
        Privileged roles will not work until this user enables MFA.
      </div>

      <.simple_form
        for={@form}
        id="user-roles_change-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div :for={{group, permission} <- @role_groups} :if={allow?(@scope, permission)} class="mt-2">
          <span class="text-lg font-bold">{group |> to_string() |> String.capitalize()}</span>

          <.input_tw
            :for={role <- @role_data[group]}
            :if={allow?(@scope, role.edit_permission)}
            name={"roles[#{role.name}]"}
            checked={role.name in @selected_roles}
            type="checkbox"
            label={role.name}
          />
        </div>

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
              Change roles
            </.button>
          </div>
        </div>
      </.simple_form>
    </div>
    """
  end

  @impl LiveComponent
  def update(%{user: user} = assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_new(:form, fn ->
      to_form(User.roles_changeset(user, user.roles))
    end)
    |> ok()
  end

  @impl LiveComponent
  def handle_event(
        "validate",
        %{"roles" => selected_roles},
        %Socket{assigns: %{scope: scope, user: user}} = socket
      ) do
    new_roles = calculate_new_roles(user, selected_roles, scope)
    changeset = User.roles_changeset(socket.assigns.user, new_roles)

    {:noreply,
     assign(socket, form: to_form(changeset, action: :validate), selected_roles: new_roles)}
  end

  def handle_event("save", %{"roles" => selected_roles}, socket) do
    %{user: %User{} = user, scope: scope} = socket.assigns
    new_roles = calculate_new_roles(user, selected_roles, scope)

    result =
      Repo.transact(fn ->
        with true <- UserLib.can_access_user?(user, scope),
             %Changeset{valid?: true} = changeset <- User.roles_changeset(user, new_roles),
             {:ok, %User{} = updated_user} <- Repo.update(changeset),
             %{} <-
               add_audit_log(scope, "Changed user roles", %{
                 user_id: user.id,
                 old_roles: user.roles,
                 new_roles: new_roles
               }) do
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
        |> put_flash(:info, "User roles changed successfully")
        |> push_patch(to: ~p"/moderation/users/#{user.id}")
        |> noreply()

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  # Remove any roles from the list of changes this user is not allowed to alter
  defp filter_selected_roles(roles, scope) do
    # Currently in the middle of making it so the roles selected are only the ones allowed
    # to be selected. Don't forget, there's a bunch of dead code to remove in the UserController

    roles
    # Reject some based on their name
    |> Enum.reject(fn {role_name, _selected} ->
      String.starts_with?(role_name, "_unused_")
    end)
    # Filter based on permissions
    |> Enum.filter(fn {role_name, _selected} ->
      %Role{} = role = RoleLib.role_data(role_name)
      allow?(scope, role.edit_permission)
    end)
  end

  defp calculate_new_roles(user, selected_roles, scope) do
    filtered_selected_roles =
      selected_roles
      |> filter_selected_roles(scope)
      |> Map.new()

    # Combine all the roles we could possibly care about
    (user.roles ++ Map.keys(filtered_selected_roles))
    |> Enum.uniq()
    # For each of the total roles, if it's in the selected roles we use that
    # but if it isn't present in the selected roles we keep it (as it will be
    # present in the existing roles)
    |> Enum.filter(fn role -> Map.get(filtered_selected_roles, role, "true") == "true" end)
    |> Enum.sort()
  end
end
