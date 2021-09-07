defmodule Teiserver.Coordinator.VoteTest do
use Central.ServerCase, async: false
  alias Teiserver.Battle.Lobby
  alias Teiserver.Common.PubsubListener
  alias Teiserver.{Client, Coordinator}
  alias Teiserver.Account.UserCache

  import Teiserver.TeiserverTestLib,
    only: [tachyon_auth_setup: 0, _tachyon_send: 2, _tachyon_recv: 1]

  setup do
    Teiserver.Coordinator.start_coordinator()
    %{socket: hsocket, user: host} = tachyon_auth_setup()
    %{socket: psocket, user: player} = tachyon_auth_setup()

    lobby_data = %{
      cmd: "c.lobby.create",
      name: "Coordinator #{:rand.uniform(999_999_999)}",
      nattype: "none",
      port: 1234,
      game_hash: "string_of_characters",
      map_hash: "string_of_characters",
      map_name: "koom valley",
      game_name: "BAR",
      engine_name: "spring-105",
      engine_version: "105.1.2.3",
      settings: %{
        max_players: 12
      }
    }
    data = %{cmd: "c.lobby.create", lobby: lobby_data}
    _tachyon_send(hsocket, data)
    reply = _tachyon_recv(hsocket)
    lobby_id = reply["lobby"]["id"]

    Lobby.start_coordinator_mode(lobby_id)
    listener = PubsubListener.new_listener(["legacy_battle_updates:#{lobby_id}"])

    # Player needs to be added to the battle
    Lobby.add_user_to_battle(player.id, lobby_id, "script_password")
    player_client = Client.get_client_by_id(player.id)
    Client.update(%{player_client |
      player: true
    }, :client_updated_battlestatus)

    {:ok, hsocket: hsocket, psocket: psocket, host: host, player: player, lobby_id: lobby_id, listener: listener}
  end

  test "moderator only command", %{lobby_id: lobby_id, host: host, hsocket: hsocket} do
    %{user: player2, socket: psocket} = tachyon_auth_setup()

    battle = Lobby.get_battle!(lobby_id)
    assert battle.coordinator_mode == true

    data = %{cmd: "c.lobby.message", userid: host.id, message: "!specunready"}
    _tachyon_send(hsocket, data)

    reply = _tachyon_recv(psocket)
    assert reply == :timeout
  end

  test "vote on a new map", %{lobby_id: lobby_id, host: host, hsocket: hsocket} do
    %{user: player2, socket: psocket} = tachyon_auth_setup()

    battle = Lobby.get_battle!(lobby_id)
    assert battle.coordinator_mode == true

    data = %{cmd: "c.lobby.message", userid: host.id, message: "!changemap map_name"}
    _tachyon_send(psocket, data)

    reply = _tachyon_recv(psocket)
    assert reply == :timeout
  end
end
