defmodule Teiserver.Protocols.Tachyon.BattleIn do
  alias Teiserver.Battle
  alias Teiserver.Protocols.Tachyon
  import Teiserver.Protocols.TachyonOut, only: [reply: 4]

  @spec do_handle(String.t(), Map.t(), Map.t()) :: Map.t()
  def do_handle("create", %{"battle" => battle_dict}, %{userid: nil} = state) do
    throw "Need to be logged in to do stuff with battles"
  end

  def do_handle("query", %{"query" => _query}, state) do
    state
  end

  def do_handle("create", %{"battle" => battle_dict}, state) do
    battle_keys = [:cmd, :name, :nattype, :password, :port, :game_hash, :map_hash, :map_name, :game_name, :engine_name, :engine_version, :settings, :ip]

    # Apply defaults
    battle =
      battle_keys
      |> Map.new(fn k -> {k, Map.get(battle_dict, to_string(k))} end)
      |> Map.put(:founder_id, state.userid)
      |> Battle.create_battle()
      |> Battle.add_battle()

    reply(:battle, :create, {:success, battle}, state)
  end
end
