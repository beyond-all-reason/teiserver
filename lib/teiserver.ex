defmodule Teiserver do
  @moduledoc false
  alias Teiserver.Data.Types, as: T

  # def icon(), do: "fa-duotone fa-robot"
  @spec icon :: String.t()
  def icon(), do: "fa-duotone fa-server"

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

  @spec user_group_id() :: integer()
  def user_group_id(), do: ConCache.get(:application_metadata_cache, "teiserver_user_group")

  @spec umbrella_group_id() :: integer()
  def umbrella_group_id(),
    do: ConCache.get(:application_metadata_cache, "teiserver_umbrella_group")

  @spec internal_group_id() :: integer()
  def internal_group_id(),
    do: ConCache.get(:application_metadata_cache, "teiserver_internal_group")

  # Designed for debugging help
  @spec tachyon(String.t() | :timeout) :: {:ok, List.t() | Map.t()} | {:error, :bad_json}
  def tachyon(v) do
    Teiserver.Protocols.TachyonLib.decode(v)
  end

  @spec accolade_status :: nil | :ok
  def accolade_status() do
    Application.put_env(:elixir, :ansi_enabled, true)
    Teiserver.Account.AccoladeLib.live_debug()
  end

  @spec manually_delete_user(T.userid()) :: {:ok, map()} | {:error, map()}
  def manually_delete_user(id) do
    Application.put_env(:elixir, :ansi_enabled, true)
    Teiserver.Admin.DeleteUserTask.delete_users([id])
  end

  @spec node_name() :: String.t()
  def node_name() do
    Application.get_env(:central, Teiserver)[:node_name] || to_string(Node.self())
  end

  # Delegate some stuff
  defdelegate rate_match(match), to: Teiserver.Game.MatchRatingLib
  defdelegate rate_match(match, override), to: Teiserver.Game.MatchRatingLib
end
