defmodule Teiserver do
  @moduledoc false
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Helpers.CacheHelper

  # def icon(), do: "fa-solid fa-robot"
  @spec icon :: String.t()
  def icon(), do: "fa-solid fa-server"

  @spec icon(:friend | :friend_request | :ignore | :relationship) :: String.t()
  def icon(:relationship), do: "fa-solid fa-users"
  def icon(:friend), do: "fa-solid fa-user-plus"
  def icon(:friend_request), do: "fa-solid fa-question"
  def icon(:ignore), do: "fa-solid fa-volume-mute"

  def hot_reload(modules) when is_list(modules) do
    modules
    |> Enum.each(fn m ->
      hot_reload(m)
    end)
  end

  def hot_reload(module) do
    :code.load_file(module)
    :code.purge(module)
    :code.load_file(module)
  end

  @spec accolade_status :: nil | :ok
  def accolade_status() do
    Application.put_env(:elixir, :ansi_enabled, true)
    Teiserver.Account.AccoladeLib.live_debug()
  end

  @spec manually_delete_user(T.userid()) :: :ok
  def manually_delete_user(id) do
    Application.put_env(:elixir, :ansi_enabled, true)
    Teiserver.Admin.DeleteUserTask.delete_users([id])
  end

  @spec node_name() :: String.t()
  def node_name() do
    Application.get_env(:teiserver, Teiserver)[:node_name] || to_string(Node.self())
  end

  # Cache stuff
  @spec cache_get(atom, any) :: any
  defdelegate cache_get(table, key), to: CacheHelper

  @spec cache_get_or_store(atom, any, function) :: any
  defdelegate cache_get_or_store(table, key, func), to: CacheHelper

  @spec cache_delete(atom, any) :: :ok | {:error, any}
  defdelegate cache_delete(table, keys), to: CacheHelper

  @spec cache_put(atom, any, any) :: :ok | {:error, any}
  defdelegate cache_put(table, key, value), to: CacheHelper

  @spec cache_insert_new(atom, any, any) :: :ok | {:error, any}
  defdelegate cache_insert_new(table, key, value), to: CacheHelper

  @spec cache_update(atom, any, any) :: :ok | {:error, any}
  defdelegate cache_update(table, key, func), to: CacheHelper

  @spec store_get(atom, any) :: any
  defdelegate store_get(table, key), to: CacheHelper

  @spec store_delete(atom, any) :: :ok
  defdelegate store_delete(table, key), to: CacheHelper

  @spec store_put(atom, any, any) :: :ok
  defdelegate store_put(table, key, value), to: CacheHelper

  @spec store_insert_new(atom, any, any) :: :ok
  defdelegate store_insert_new(table, key, value), to: CacheHelper

  @spec store_update(atom, any, function()) :: :ok
  defdelegate store_update(table, key, func), to: CacheHelper

  @spec store_get_or_store(atom, any, function) :: any
  defdelegate store_get_or_store(table, key, func), to: CacheHelper

  # Delegate some stuff
  defdelegate rate_match(match), to: Teiserver.Game.MatchRatingLib
  defdelegate rate_match(match, override), to: Teiserver.Game.MatchRatingLib
end
