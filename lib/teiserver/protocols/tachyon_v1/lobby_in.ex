defmodule Teiserver.Protocols.Tachyon.V1.LobbyIn do
  alias Teiserver.Battle.Lobby
  alias Teiserver.{Client, Coordinator}
  import Teiserver.Protocols.Tachyon.V1.TachyonOut, only: [reply: 4]
  alias Teiserver.Protocols.TachyonLib
  alias Phoenix.PubSub
  require Logger
  alias Teiserver.Data.Types, as: T

  @spec do_handle(String.t(), Map.t(), T.tachyon_tcp_state()) :: T.tachyon_tcp_state()
  def do_handle("query", %{"query" => query}, state) do
    lobby_list = Lobby.list_lobbies()
    |> TachyonLib.query(:locked, query["locked"])
    |> TachyonLib.query(:in_progress, query["in_progress"])

    reply(:lobby, :query, lobby_list, state)

    # `player_count` - Integer, a count of the number of players in the battle
    # `spectator_count` - Integer, a count of the number of spectators in the battle
    # `user_count` - Integer, a count of the number of players and spectators in the battle
    # `player_list` - List (User.id), A list of player ids in the battle
    # `spectator_list` - List (User.id), A list of spectator ids in the battle
    # `user_list` - List (User.id), A list of player and spectator ids in the battle
  end
  def do_handle("query", _, state) do
    reply(:system, :error, %{error: "no query supplied", location: "c.lobby.query"}, state)
  end

  def do_handle("create", _, %{userid: nil} = state), do: reply(:system, :nouser, nil, state)
  def do_handle("create", %{"lobby" => lobby_dict}, state) do
    lobby_keys = [:cmd, :name, :nattype, :password, :port, :game_hash, :map_hash, :map_name, :game_name, :engine_name, :engine_version, :settings, :ip]

    # Apply defaults
    if Lobby.allow?(state.userid, :host, -1) do
      lobby =
        lobby_keys
        |> Map.new(fn k -> {k, Map.get(lobby_dict, to_string(k))} end)
        |> Map.put(:founder_id, state.userid)
        |> Map.put(:founder_name, state.username)
        |> Map.put(:ip, "127.0.0.1")
        |> Lobby.create_lobby()
        |> Lobby.add_lobby()

      send(self(), {:action, {:host_lobby, lobby.id}})
      reply(:lobby, :create, {:success, lobby}, state)
    else
      reply(:lobby, :create, {:failure, "Permission denied"}, state)
    end
  end

  def do_handle("join", _, %{userid: nil} = state), do: reply(:system, :nouser, nil, state)
  def do_handle("join", data, state) do
    case Lobby.can_join?(state.userid, data["lobby_id"], data["password"]) do
      {:waiting_on_host, script_password} ->
        send(self(), {:action, {:set_script_password, script_password}})
        reply(:lobby, :join, :waiting, state)

      {:failure, reason} ->
        reply(:lobby, :join, {:failure, reason}, state)
    end
  end

  def do_handle("update_status", _, %{userid: nil} = state), do: reply(:system, :nouser, nil, state)
  def do_handle("update_status", _, %{lobby_id: nil} = state), do: reply(:system, :nolobby, nil, state)
  def do_handle("update_status", new_status, state) do
    updates =
      new_status
      |> Map.take(~w(ready team_number team_colour ally_team_number player sync side))
      |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)

    new_client =
      Client.get_client_by_id(state.userid)
      |> Map.merge(updates)

    if Lobby.allow?(state.userid, :my_battlestatus, state.lobby_id) do
      case Coordinator.attempt_battlestatus_update(new_client, state.lobby_id) do
        {true, allowed_client} ->
          Client.update(allowed_client, :client_updated_battlestatus)
        {false, _} ->
          :ok
      end
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
