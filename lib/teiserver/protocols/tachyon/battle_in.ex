defmodule Teiserver.Protocols.Tachyon.BattleIn do
  alias Teiserver.Battle.BattleLobby
  alias Teiserver.Client
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
      |> Map.put(:founder_name, state.username)
      |> Map.put(:ip, "127.0.0.1")
      |> BattleLobby.create_battle()
      |> BattleLobby.add_battle()

    new_state = %{state | battle_id: battle.id, battle_host: true}
    reply(:battle, :create, {:success, battle}, new_state)
  end

  def do_handle("join", _, %{userid: nil} = state), do: reply(:system, :nouser, nil, state)
  def do_handle("join", data, state) do
    case BattleLobby.can_join?(state.userid, data["battle_id"], data["password"]) do
      {:waiting_on_host, _script_password} ->
        reply(:battle, :join, :waiting, state)

      {:failure, reason} ->
        reply(:battle, :join, {:failure, reason}, state)
    end
  end

  def do_handle("update_status", _, %{userid: nil} = state), do: reply(:system, :nouser, nil, state)
  def do_handle("update_status", new_status, state) do
    updates =
      new_status
      |> Map.take(~w(ready team_number team_colour ally_team_number player sync side))
      |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)

    new_client =
      Client.get_client_by_id(state.userid)
      |> Map.merge(updates)

    if BattleLobby.allow?(state.userid, :mybattlestatus, state.battle_id) do
      Client.update(new_client, :client_updated_battlestatus)
    end
    state
  end

  def do_handle("respond_to_join_request", data, %{battle_id: battle_id} = state) do
    userid = int_parse(data["userid"])

    case data["response"] do
      "approve" ->
        BattleLobby.accept_join_request(userid, battle_id)

      "reject" ->
        BattleLobby.deny_join_request(userid, battle_id, data["reason"])
    end
    state
  end

  def do_handle("message", _, %{userid: nil} = state), do: reply(:system, :nouser, nil, state)
  def do_handle("message", _, %{battle_id: nil} = state) do
    reply(:battle, :message, {:failure, "Not currently in a battle"}, state)
  end
  def do_handle("message", %{"message" => msg}, state) do
    if BattleLobby.allow?(state.userid, :saybattle, state.battle_id) do
      BattleLobby.say(state.userid, msg, state.battle_id)
    end
    state
  end

  def do_handle("leave", _, %{userid: nil} = state), do: reply(:system, :nouser, nil, state)
  def do_handle("leave", _, %{battle_id: nil} = state) do
    reply(:battle, :leave, {:failure, "Not currently in a battle"}, state)
  end

  def do_handle("leave", _, state) do
    PubSub.unsubscribe(Central.PubSub, "legacy_battle_updates:#{state.battle_id}")
    BattleLobby.remove_user_from_battle(state.userid, state.battle_id)
    new_state = %{state | battle_id: nil, battle_host: false}
    reply(:battle, :leave, {:success, nil}, new_state)
  end
end
