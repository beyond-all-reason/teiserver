defmodule Teiserver.Account.AuthLib do
  @moduledoc """
  Module with functions for working with authorisation/permission checks
  """

  alias Phoenix.LiveView
  alias Phoenix.LiveView.Socket
  alias Plug.Conn
  alias Teiserver.Account

  require Logger

  @spec icon :: String.t()
  def icon, do: "fa-solid fa-address-card"

  def mfa_roles do
    ~w[Server Admin]s
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
    %{permissions: permissions_held} = conn.assigns[:current_user]

    permission_test(permissions_held, permissions_required)
  end

  # Socket
  def allow?(%Socket{} = socket, permissions_required) do
    %{permissions: permissions_held} = socket.assigns[:current_user]

    permission_test(permissions_held, permissions_required)
  end

  # This allows us to use something with permissions in it
  def allow?(%{permissions: permissions_held}, permissions_required) do
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
    Logger.debug(
      "Permission test, has: #{Kernel.inspect(permissions_held)}, needs: #{Kernel.inspect(permission_required)}"
    )

    cond do
      # Enum.member?(Application.get_env(:teiserver, TeiserverWeb)[:universal_permissions], permission_required) -> true
      permissions_held == nil ->
        Logger.debug("AuthLib.allow?() -> No permissions held")
        false

      # Server devs always have permission
      Enum.member?(permissions_held, "Server") && permission_required != "debug" ->
        true

      # Standard "do you have permission" response
      Enum.member?(permissions_held, permission_required) ->
        true

      # Default to not having permission
      true ->
        Logger.debug("AuthLib.allow?() -> Permission not found: #{permission_required}")
        false
    end
  end

  @doc """
  Allows us to perform an auth check and force a redirect
  """
  @spec mount_require_all(Plug.Conn.t() | Phoenix.LiveView.Socket.t(), String.t() | [String.t()]) ::
          Phoenix.LiveView.Socket
  def mount_require_all(obj, requirements) do
    if do_require(obj, List.flatten([requirements]), :all) do
      obj
    else
      obj
      |> LiveView.put_flash(:warning, "You do not have permission to view this page.")
      |> LiveView.redirect(to: "/")
    end
  end

  @spec mount_require_any(
          map() | Plug.Conn.t() | Phoenix.LiveView.Socket.t(),
          String.t() | [String.t()]
        ) :: Phoenix.LiveView.Socket
  def mount_require_any(obj, requirements) do
    if do_require(obj, List.flatten([requirements]), :any) do
      obj
    else
      obj
      |> LiveView.put_flash(:warning, "You do not have permission to view this page.")
      |> LiveView.redirect(to: "/")
    end
  end

  defp do_require(%Plug.Conn{} = conn, requirements, all_or_any) do
    do_require(conn.assigns[:current_user].permissions, requirements, all_or_any)
  end

  # Socket
  defp do_require(%Phoenix.LiveView.Socket{} = socket, requirements, all_or_any) do
    do_require(socket.assigns[:current_user].permissions, requirements, all_or_any)
  end

  defp do_require(permissions_held, requirements, :all) do
    Enum.all?(
      requirements,
      fn p ->
        allow?(permissions_held, p)
      end
    )
  end

  defp do_require(permissions_held, requirements, :any) do
    Enum.any?(
      requirements,
      fn p ->
        allow?(permissions_held, p)
      end
    )
  end

  @doc """
  Returns true if the user_id in question has an active totp
  """
  @spec has_active_mfa?(Teiserver.Account.User.id()) :: boolean()
  def has_active_mfa?(user_id) do
    user_id != nil and Account.get_user_totp_status(user_id) == :active
  end

  @doc """
  Given a user_id, checks for the presence of any MFA gated roles, if any
  are possessed then also checks for MFA. If no MFA is present then the
  roles are removed.
  """
  @spec maybe_remove_mfa_roles(Teiserver.Account.User.id()) :: :removed | :nochange
  def maybe_remove_mfa_roles(user_id) do
    user = Account.get_user(user_id)
    mfa_required = Application.get_env(:teiserver, Teiserver)[:require_mfa_for_privileged_roles]

    if mfa_required and contains_mfa_role?(user.roles) do
      # If the user has an MFA role then do an empty update
      # and the update code will decide if how to alter the user
      user
      |> Account.script_update_user(%{})

      :removed
    else
      :nochange
    end
  end

  @doc """
  Given a list of roles, remove any MFA guarded roles from the list
  """
  @spec remove_mfa_roles_from_list([String.t()]) :: [String.t()]
  def remove_mfa_roles_from_list(roles) do
    Enum.reject(roles, fn role ->
      Enum.member?(mfa_roles(), role)
    end)
  end

  @spec contains_mfa_role?([String.t()]) :: boolean()
  def contains_mfa_role?(role_list) do
    role_set = MapSet.new(role_list)
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
