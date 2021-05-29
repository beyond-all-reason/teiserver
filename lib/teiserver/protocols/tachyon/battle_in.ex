defmodule Teiserver.Protocols.Tachyon.BattleIn do
  alias Teiserver.Battle
  # alias Teiserver.Protocols.Tachyon
  import Teiserver.Protocols.TachyonOut, only: [reply: 4]
  import Central.Helpers.NumberHelper, only: [int_parse: 1]
  alias Phoenix.PubSub

  @spec do_handle(String.t(), Map.t(), Map.t()) :: Map.t()
  def do_handle("query", %{"query" => _query}, state) do
    state
  end

  def do_handle("create", _, %{userid: nil} = state), do: reply(:system, :nouser, nil, state)
  def do_handle("create", %{"battle" => battle_dict}, state) do
    battle_keys = [:cmd, :name, :nattype, :password, :port, :game_hash, :map_hash, :map_name, :game_name, :engine_name, :engine_version, :settings, :ip]

    # Apply defaults
    battle =
      battle_keys
      |> Map.new(fn k -> {k, Map.get(battle_dict, to_string(k))} end)
      |> Map.put(:founder_id, state.userid)
      |> Battle.create_battle()
      |> Battle.add_battle()

    new_state = %{state | battle_id: battle.id, battle_host: true}
    reply(:battle, :create, {:success, battle}, new_state)
  end

  def do_handle("join", _, %{userid: nil} = state), do: reply(:system, :nouser, nil, state)
  def do_handle("join", data, state) do
    case Battle.can_join?(state.user, data["battle_id"], data["password"]) do
      {:waiting_on_host, _script_password} ->
        reply(:battle, :join, :waiting, state)

      {:failure, reason} ->
        reply(:battle, :join, {:failure, reason}, state)
    end

    # # Apply defaults
    # battle =
    #   battle_keys
    #   |> Map.new(fn k -> {k, Map.get(battle_dict, to_string(k))} end)
    #   |> Map.put(:founder_id, state.userid)
    #   |> Battle.join_battle()
    #   |> Battle.add_battle()

    # new_state = %{state | battle_id: battle.id, battle_host: true}
    # reply(:battle, :create, {:success, battle}, new_state)
  end

  def do_handle("respond_to_join_request", data, %{battle_id: battle_id} = state) do
    userid = int_parse(data["userid"])

    case data["response"] do
      "approve" ->
        Battle.accept_join_request(userid, battle_id)

      "reject" ->
        Battle.deny_join_request(userid, battle_id, data["reason"])
    end
    state
  end

  def do_handle("leave", _, %{userid: nil} = state), do: reply(:system, :nouser, nil, state)
  def do_handle("leave", _, %{battle_id: nil} = state) do
    reply(:battle, :leave, {:failure, "Not currently in a battle"}, state)
  end

  def do_handle("leave", _, state) do
    PubSub.unsubscribe(Central.PubSub, "battle_updates:#{state.battle_id}")
    Battle.remove_user_from_battle(state.userid, state.battle_id)
    new_state = %{state | battle_id: nil, battle_host: false}
    reply(:battle, :leave, {:success, nil}, new_state)
  end
end
