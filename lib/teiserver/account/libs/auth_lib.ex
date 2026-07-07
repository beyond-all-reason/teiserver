defmodule Teiserver.Account.AuthLib do
  @moduledoc """
  Module with functions for working with authorisation/permission checks
  """

  alias Phoenix.LiveView
  alias Phoenix.LiveView.Socket
  alias Plug.Conn
  alias Teiserver.Account
  alias Teiserver.Account.Auth
  alias Teiserver.Account.RoleLib

  @spec icon :: String.t()
  def icon, do: "fa-solid fa-address-card"

  def mfa_roles do
    ~w[Server Admin Moderator Overwatch Contributor]s
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

  @spec get_permissions_from_roles([String.t()]) :: [String.t()]
  def get_permissions_from_roles(roles) do
    roles
    |> Enum.map(fn role_name ->
      case RoleLib.role_data(role_name) do
        nil -> [role_name]
        %{contains: permissions} -> [role_name | permissions]
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
          map() | Conn.t() | Socket.t() | Teiserver.Account.User.t(),
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

  # User and CacheUser
  def allow?(%{id: id, roles: roles}, permissions_required) do
    permissions_held = get_permissions_from_roles(roles)

    mfa_test(id, permissions_required) and
      permission_test(permissions_held, permissions_required)
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
        not Auth.is_bot?(user)
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
end
