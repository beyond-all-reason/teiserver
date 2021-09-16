defmodule Teiserver.Protocols.Tachyon.LobbyIn do
  alias Teiserver.Battle.Lobby
  alias Teiserver.{Client, Coordinator}
  import Teiserver.Protocols.TachyonOut, only: [reply: 4]
  import Central.Helpers.NumberHelper, only: [int_parse: 1]
  alias Phoenix.PubSub
  require Logger

  @spec do_handle(String.t(), Map.t(), Map.t()) :: Map.t()
  def do_handle("query", %{"query" => _query}, state) do
    state
  end

  def do_handle("create", _, %{userid: nil} = state), do: reply(:system, :nouser, nil, state)
  def do_handle("create", %{"lobby" => lobby_dict}, state) do
    lobby_keys = [:cmd, :name, :nattype, :password, :port, :game_hash, :map_hash, :map_name, :game_name, :engine_name, :engine_version, :settings, :ip]

    # Apply defaults
    lobby =
      lobby_keys
      |> Map.new(fn k -> {k, Map.get(lobby_dict, to_string(k))} end)
      |> Map.put(:founder_id, state.userid)
      |> Map.put(:founder_name, state.username)
      |> Map.put(:ip, "127.0.0.1")
      |> Lobby.create_lobby()
      |> Lobby.add_lobby()

    new_state = %{state | lobby_id: lobby.id, lobby_host: true}
    reply(:lobby, :create, {:success, lobby}, new_state)
  end

  def do_handle("join", _, %{userid: nil} = state), do: reply(:system, :nouser, nil, state)
  def do_handle("join", data, state) do
    case Lobby.can_join?(state.userid, data["lobby_id"], data["password"]) do
      {:waiting_on_host, _script_password} ->
        reply(:lobby, :join, :waiting, state)

      {:failure, reason} ->
        reply(:lobby, :join, {:failure, reason}, state)
    end
  end

  def do_handle("update_status", _, %{userid: nil} = state), do: reply(:system, :nouser, nil, state)
  def do_handle("update_status", _, %{battle: nil} = state), do: reply(:system, :nolobby, nil, state)
  def do_handle("update_status", new_status, state) do
    updates =
      new_status
      |> Map.take(~w(ready team_number team_colour ally_team_number player sync side))
      |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)

    new_client =
      Client.get_client_by_id(state.userid)
      |> Map.merge(updates)

    if Lobby.allow?(state.userid, :mylobbystatus, state.lobby_id) do
      if Coordinator.allow_battlestatus_update?(new_client, state.lobby_id) do
        Client.update(new_client, :client_updated_battlestatus)
      end
    end
    state
  end

  def do_handle("respond_to_join_request", data, %{lobby_id: lobby_id} = state) do
    userid = int_parse(data["userid"])

    case data["response"] do
      "approve" ->
        Lobby.accept_join_request(userid, lobby_id)

      "reject" ->
        Lobby.deny_join_request(userid, lobby_id, data["reason"])
    end
    state
  end

  def do_handle("message", _, %{userid: nil} = state), do: reply(:system, :nouser, nil, state)
  def do_handle("message", _, %{lobby_id: nil} = state) do
    reply(:lobby, :message, {:failure, "Not currently in a lobby"}, state)
  end
  def do_handle("message", %{"message" => msg}, state) do
    if Lobby.allow?(state.userid, :saylobby, state.lobby_id) do
      Lobby.say(state.userid, msg, state.lobby_id)
    end
    state
  end

  def do_handle("leave", _, %{userid: nil} = state), do: reply(:system, :nouser, nil, state)
  def do_handle("leave", _, %{lobby_id: nil} = state) do
    reply(:lobby, :leave, {:failure, "Not currently in a lobby"}, state)
  end

  def do_handle("leave", _, state) do
    PubSub.unsubscribe(Central.PubSub, "legacy_battle_updates:#{state.lobby_id}")
    Lobby.remove_user_from_battle(state.userid, state.lobby_id)
    new_state = %{state | lobby_id: nil, lobby_host: false}
    reply(:lobby, :leave, {:success, nil}, new_state)
  end
end
