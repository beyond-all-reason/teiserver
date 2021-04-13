defmodule Central.Account.AuthLib do
  require Logger

  alias Central.Account.User
  alias Central.Account.AuthGroups.Server

  @spec icon :: String.t()
  def icon(), do: "far fa-address-card"

  @spec get_all_permission_sets() :: Map.t()
  def get_all_permission_sets do
    Server.get_all()
  end

  @spec get_all_permissions() :: [String.t()]
  def get_all_permissions do
    Server.get_all()
    |> Enum.map(fn {_, ps} -> ps end)
    |> List.flatten()
    |> split_permissions
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
      |> Enum.map(fn p -> p |> String.split(".") |> hd end)
      |> Enum.uniq()

    permission_list ++ sections ++ modules
  end

  def add_permission_set(module, section, auths) do
    permissions =
      auths
      |> Enum.map(fn a ->
        "#{module}.#{section}.#{a}"
      end)

    Server.add(module, section, permissions)
  end

  # If you don't need permissions then lets not bother checking
  @spec allow?(Map.t() | Plug.Conn.t() | [String.t()], String.t() | [String.t()]) :: boolean
  def allow?(_, nil), do: true
  def allow?(_, ""), do: true
  def allow?(_, []), do: true

  # Handle conn
  def allow?(%Plug.Conn{} = conn, permission_required) do
    allow?(conn.assigns[:current_user], permission_required)
  end

  # This allows us to use a modified liveview socket
  def allow?(%{permissions: permissions}, permission_required) do
    allow?(permissions, permission_required)
  end

  # Handle users
  def allow?(%{} = user, permission_required) do
    allow?(user.permissions, permission_required)
  end

  def allow?(permissions_held, permission_required) when is_list(permission_required) do
    Enum.all?(
      permission_required,
      fn p ->
        allow?(permissions_held, p)
      end
    )
  end

  def allow?(permissions_held, permission_required) do
    # If dev or test then check for non-existant permissions
    # if Enum.member?([:test, :dev], Mix.env) do
    #   # for p <- get_all_permissions() do
    #   #   IO.puts p
    #   # end

    #   if not Enum.member?(get_all_permissions(), permission_required) do
    #     raise "Permission required: '#{permission_required}' was not found"
    #   end
    # end

    cond do
      # Enum.member?(Application.get_env(:centaur, CentralWeb)[:universal_permissions], permission_required) -> true
      permissions_held == nil ->
        Logger.debug("AuthLib.allow?() -> No permissions held")
        false

      # Developers always have permission
      Enum.member?(permissions_held, "admin.dev.developer") && permission_required != "debug" ->
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
end
