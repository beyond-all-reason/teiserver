defmodule Teiserver.Account.AuthLib do
  @moduledoc """
  Module with functions for working with authorisation/permission checks
  """

  alias Phoenix.LiveView
  alias Phoenix.LiveView.Socket
  alias Plug.Conn
  alias Teiserver.Account
  alias Teiserver.Account.Role
  alias Teiserver.Account.RoleLib
  alias Teiserver.Account.Scope
  alias Teiserver.Account.TOTPLib
  alias Teiserver.Account.User
  alias Teiserver.General.RateLimit

  @spec icon :: String.t()
  def icon, do: "fa-solid fa-address-card"

  def mfa_roles do
    [
      "Server",
      "Admin",
      "Senior moderator",
      "Moderator",
      "Reviewer",
      "Overwatch",
      "Technician",
      "Contributor",
      "Event Organizer",
      "Caster",
      "Staff"
    ]
  end

  @spec get_all_permission_sets() :: list()
  def get_all_permission_sets do
    Teiserver.store_get(:auth_group_store, :all)
    |> Enum.map(fn key -> {key, get_permission_set(key)} end)
  end

  @spec split_permissions([String.t()]) :: [String.t()]
  def split_permissions(permission_list) do
    sections =
      permission_list
      |> Enum.map(fn p ->
        p
        |> String.split(".")
        |> Enum.take(2)
        |> Enum.join(".")
      end)
      |> Enum.uniq()

    modules =
      permission_list
      |> Enum.map(fn p -> p |> String.split(".") |> hd() end)
      |> Enum.uniq()

    permission_list ++ sections ++ modules
  end

  @doc """
  Given a list of roles, extract a combined list of all the permissions granted by these roles.
  """
  @spec get_permissions_from_roles([String.t()]) :: [String.t()]
  def get_permissions_from_roles(roles) do
    roles
    |> Enum.map(fn role_name ->
      case RoleLib.role_data(role_name) do
        nil -> [role_name]
        %Role{contains: permissions} -> [role_name | permissions]
      end
    end)
    |> List.flatten()
    |> Enum.uniq()
  end

  @spec get_permission_set({String.t(), String.t()}) :: [String.t()]
  def get_permission_set(key) do
    Teiserver.store_get(:auth_group_store, key)
  end

  @spec add_permission_set(String.t(), String.t(), [String.t()]) :: :ok
  def add_permission_set(module, section, auths) do
    permissions =
      auths
      |> Enum.map(fn a ->
        "#{module}.#{section}.#{a}"
      end)

    key = {module, section}
    all_auth_keys = [key | Teiserver.store_get(:auth_group_store, :all) || []]

    Teiserver.store_put(:auth_group_store, key, permissions)
    Teiserver.store_put(:auth_group_store, :all, all_auth_keys)
    :ok
  end

  def allow_any?(conn, perms) do
    perms
    |> Enum.map(fn p -> allow?(conn, p) end)
    |> Enum.any?()
  end

  # If you don't need permissions then lets not bother checking
  @spec allow?(
          map() | Conn.t() | Socket.t() | Teiserver.Account.User.t() | Scope.t(),
          String.t() | [String.t()]
        ) :: boolean
  def allow?(nil, _any), do: false
  def allow?(_permissions, nil), do: true
  def allow?(_permissions, ""), do: true
  def allow?(_permissions, []), do: true

  # Handle conn
  def allow?(%Conn{} = conn, permissions_required) do
    %{id: id, roles: roles} = conn.assigns[:current_user]
    permissions_held = get_permissions_from_roles(roles)

    mfa_test(id, permissions_required) and
      permission_test(permissions_held, permissions_required)
  end

  # Socket
  def allow?(%Socket{} = socket, permissions_required) do
    %{id: id, roles: roles} = socket.assigns[:current_user]
    permissions_held = get_permissions_from_roles(roles)

    mfa_test(id, permissions_required) and
      permission_test(permissions_held, permissions_required)
  end

  # Scope
  def allow?(%Scope{user: user} = _scope, permissions_required),
    do: allow?(user, permissions_required)

  # User
  def allow?(%{id: id, roles: roles}, permissions_required) do
    permissions_held = get_permissions_from_roles(roles)

    mfa_test(id, permissions_required) and
      permission_test(permissions_held, permissions_required)
  end

  # credo:disable-for-lines:5 Credo.Check.Readability.PredicateFunctionNames
  @spec is_bot?(User.id() | User.t() | nil) :: boolean()
  def is_bot?(nil), do: false
  def is_bot?(userid) when is_integer(userid), do: is_bot?(Account.get_user(userid))
  def is_bot?(%User{} = %{roles: roles}), do: Enum.member?(roles, "Bot")
  def is_bot?(_user), do: false

  @spec moderator?(User.id() | User.t() | nil) :: boolean()
  def moderator?(nil), do: false

  def moderator?(userid) when is_integer(userid),
    do: moderator?(Account.get_user(userid))

  def moderator?(%User{} = user), do: allow?(user, "Moderator")
  def moderator?(_user), do: false

  # credo:disable-for-lines:8 Credo.Check.Readability.PredicateFunctionNames
  @spec is_event_organizer?(User.id() | User.t() | nil) :: boolean()
  def is_event_organizer?(nil), do: false

  def is_event_organizer?(userid) when is_integer(userid),
    do: is_event_organizer?(Account.get_user(userid))

  def is_event_organizer?(%User{} = user), do: allow?(user, "Event Organizer")
  def is_event_organizer?(_user), do: false

  @spec contributor?(User.id() | User.t() | nil) :: boolean()
  def contributor?(nil), do: false

  def contributor?(userid) when is_integer(userid),
    do: contributor?(Account.get_user(userid))

  def contributor?(%User{} = user), do: allow?(user, "Contributor")
  def contributor?(_user), do: false

  @spec verified?(User.id() | User.t() | nil) :: boolean()
  def verified?(nil), do: false

  def verified?(userid) when is_integer(userid),
    do: verified?(Account.get_user(userid))

  def verified?(%User{} = %{roles: roles}), do: Enum.member?(roles, "Verified")
  def verified?(_user), do: false

  @spec admin?(User.id() | User.t() | nil) :: boolean()
  def admin?(nil), do: false
  def admin?(userid) when is_integer(userid), do: admin?(Account.get_user(userid))
  def admin?(%User{} = user), do: allow?(user, "Admin")
  def admin?(_user), do: false

  @spec vip?(User.id() | User.t() | nil) :: boolean()
  def vip?(nil), do: false
  def vip?(userid) when is_integer(userid), do: vip?(Account.get_user(userid))
  def vip?(%User{} = user), do: allow?(user, "VIP")
  def vip?(_user), do: false

  @spec trusted?(User.id() | User.t() | nil) :: boolean()
  def trusted?(nil), do: false
  def trusted?(userid) when is_integer(userid), do: trusted?(Account.get_user(userid))
  def trusted?(%User{} = user), do: allow?(user, "Trusted")
  def trusted?(_user), do: false

  @doc """
  If a user possesses any of these roles it returns true
  """
  @spec has_any_role?(User.id() | User.t() | nil, String.t() | [String.t()]) :: boolean()
  def has_any_role?(nil, _roles), do: false

  def has_any_role?(userid, roles) when is_integer(userid),
    do: has_any_role?(Account.get_user(userid), roles)

  def has_any_role?(%User{} = user, roles) when is_list(roles) do
    roles
    |> Enum.map(fn role -> Enum.member?(user.roles, role) end)
    |> Enum.any?()
  end

  def has_any_role?(user, role), do: has_any_role?(user, [role])

  @doc """
  If a user possesses all of these roles it returns true, if any are lacking it returns false
  """
  @spec has_all_roles?(User.id() | User.t() | nil, String.t() | [String.t()]) :: boolean()
  def has_all_roles?(nil, _roles), do: false

  def has_all_roles?(userid, roles) when is_integer(userid),
    do: has_all_roles?(Account.get_user(userid), roles)

  def has_all_roles?(%User{} = user, roles) when is_list(roles) do
    roles
    |> Enum.map(fn role -> Enum.member?(user.roles, role) end)
    |> Enum.all?()
  end

  def has_all_roles?(user, role), do: has_all_roles?(user, [role])

  @spec add_roles(User.id() | User.t() | nil, [String.t()]) :: nil | {:ok, User.t()}
  def add_roles(nil, _roles), do: nil
  def add_roles(_user, []), do: nil
  def add_roles(_user, nil), do: nil

  def add_roles(userid, roles) when is_integer(userid),
    do: add_roles(Account.get_user(userid), roles)

  def add_roles(%User{} = user, roles) do
    new_roles = Enum.uniq(roles ++ user.roles)
    Account.script_update_user(user, %{roles: new_roles})
  end

  @spec remove_roles(User.id() | User.t() | nil, [String.t()]) :: nil | User.t()
  def remove_roles(nil, _roles), do: nil
  def remove_roles(_user, []), do: nil

  def remove_roles(userid, roles) when is_integer(userid),
    do: remove_roles(Account.get_user(userid), roles)

  def remove_roles(%User{} = user, removed_roles) do
    new_roles =
      user.roles
      |> Enum.reject(fn r -> Enum.member?(removed_roles, r) end)

    Account.script_update_user(user, %{roles: new_roles})
  end

  @doc """
  Performs a rate-limit check for a login attempt
  """
  @spec can_login?(User.t()) :: boolean()
  def can_login?(%User{id: id}) do
    key = "failed-login:#{id}"
    scale = :timer.minutes(1)
    limit = 4

    case RateLimit.hit(key, scale, limit) do
      {:allow, _current_count} -> true
      {:deny, _ms_until_next_window} -> false
    end
  end

  # The testing of permissions required against permissions held
  defp permission_test(permissions_held, permission_required) when is_list(permission_required) do
    Enum.all?(
      permission_required,
      fn p ->
        permission_test(permissions_held, p)
      end
    )
  end

  defp permission_test(_permissions, "account") do
    true
  end

  defp permission_test(permissions_held, permission_required) do
    cond do
      Enum.empty?(permissions_held) ->
        false

      # Server devs always have permission
      Enum.member?(permissions_held, "Server") && permission_required != "debug" ->
        true

      # Standard "do you have permission" response
      Enum.member?(permissions_held, permission_required) ->
        true

      # Default to not having permission
      true ->
        false
    end
  end

  @doc """
  Allows us to perform an auth check and force a redirect
  """
  @spec mount_require_all(Phoenix.LiveView.Socket.t(), String.t() | [String.t()]) ::
          Phoenix.LiveView.Socket | map()
  def mount_require_all(socket, requirements) do
    if allow?(socket, List.flatten([requirements])) do
      socket
    else
      socket
      |> LiveView.put_flash(:warning, "You do not have permission to view this page.")
      |> LiveView.redirect(to: "/")
    end
  end

  @spec mount_require_any(Phoenix.LiveView.Socket.t(), String.t() | [String.t()]) ::
          Phoenix.LiveView.Socket | map()
  def mount_require_any(socket, requirements) do
    if allow_any?(socket, List.flatten([requirements])) do
      socket
    else
      socket
      |> LiveView.put_flash(:warning, "You do not have permission to view this page.")
      |> LiveView.redirect(to: "/")
    end
  end

  # If the permission requires MFA then check for it, otherwise return true
  # as their MFA status doesn't matter
  # if mfa_required? is not set then it will always return true
  # bots do not require MFA
  defp mfa_test(user, permissions_required) do
    conditions =
      Enum.all?([
        mfa_required?(),
        contains_mfa_role?(permissions_required),
        not is_bot?(user)
      ])

    if conditions do
      has_active_mfa?(user)
    else
      true
    end
  end

  @doc """
  Returns true if the user_id in question has an active totp
  """
  @spec has_active_mfa?(Teiserver.Account.User.id()) :: boolean()
  def has_active_mfa?(user_id) do
    Teiserver.cache_get_or_store(:user_mfa_active, user_id, fn ->
      user_id != nil and
        Account.get_user_totp_status(user_id) == :active
    end)
  end

  def mfa_required? do
    Application.get_env(:teiserver, Teiserver)[:require_mfa_for_privileged_roles]
  end

  @spec contains_mfa_role?([String.t()]) :: boolean()
  def contains_mfa_role?(role_list) do
    role_set = List.wrap(role_list) |> MapSet.new()
    mfa_role_set = MapSet.new(mfa_roles())
    intersection = MapSet.intersection(role_set, mfa_role_set)

    not Enum.empty?(intersection)
  end

  # This is used as part of the permission system getting the current user
  @spec current_user(Plug.Conn.t()) :: Teiserver.Account.User.t() | nil
  def current_user(conn) do
    conn.assigns[:current_user]
  end

  @doc """
  Returns how many seconds ago they last used their MFA
  """
  @spec get_user_mfa_age_in_seconds(User.id()) :: :inactive | non_neg_integer()
  def get_user_mfa_age_in_seconds(user_id) do
    case TOTPLib.get_last_used(user_id) do
      :inactive ->
        :inactive

      %DateTime{} = last_used_dt ->
        DateTime.diff(DateTime.utc_now(), last_used_dt)
    end
  end

  @doc """
  Returns a boolean saying if the MFA of a user needs to refresh (it was last used
  more than 5 minutes ago), in the event the user has no MFA it will not require a refresh.
  """
  @spec need_to_mfa_refresh?(User.id()) :: boolean()
  def need_to_mfa_refresh?(user_id) do
    max_age = Application.get_env(:teiserver, Teiserver)[:mfa_privilege_refresh_max_age] || 300

    case get_user_mfa_age_in_seconds(user_id) do
      :inactive -> false
      age -> age > max_age
    end
  end
end
