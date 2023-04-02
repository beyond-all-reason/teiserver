defmodule Teiserver.Coordinator.LockTest do
  use Central.ServerCase, async: false
  alias Teiserver.Battle.Lobby
  alias Teiserver.Common.PubsubListener
  alias Teiserver.{Client, Coordinator}

  import Teiserver.TeiserverTestLib,
    only: [tachyon_auth_setup: 0, _tachyon_send: 2, _tachyon_recv: 1]

  setup do
    Coordinator.start_coordinator()
    %{socket: hsocket, user: host} = tachyon_auth_setup()
    %{socket: psocket, user: player} = tachyon_auth_setup()

    battle_data = %{
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

    data = %{cmd: "c.lobby.create", lobby: battle_data}
    _tachyon_send(hsocket, data)
    [reply] = _tachyon_recv(hsocket)
    lobby_id = reply["lobby"]["id"]

    listener = PubsubListener.new_listener(["legacy_battle_updates:#{lobby_id}"])

    # Player needs to be added to the battle
    Lobby.force_add_user_to_lobby(player.id, lobby_id)
    :timer.sleep(100)
    player_client = Client.get_client_by_id(player.id)

    Client.update(
      %{player_client | player: true, ready: true},
      :client_updated_battlestatus
    )

    # Add user message
    _tachyon_recv(hsocket)

    # Battlestatus message
    _tachyon_recv(hsocket)

    {:ok,
     hsocket: hsocket,
     psocket: psocket,
     host: host,
     player: player,
     lobby_id: lobby_id,
     listener: listener}
  end

  test "lock and unlock", %{hsocket: hsocket, lobby_id: lobby_id} do
    locks = Coordinator.call_consul(lobby_id, {:get, :locks})
    assert locks == []

    # Add a lock
    _tachyon_send(hsocket, %{cmd: "c.lobby.message", message: "$lock team"})
    locks = Coordinator.call_consul(lobby_id, {:get, :locks})
    assert locks == [:team]

    # Add another lock
    _tachyon_send(hsocket, %{cmd: "c.lobby.message", message: "$lock allyid"})
    locks = Coordinator.call_consul(lobby_id, {:get, :locks})
    assert locks == [:allyid, :team]

    # Add a duplicate lock
    _tachyon_send(hsocket, %{cmd: "c.lobby.message", message: "$lock allyid"})
    locks = Coordinator.call_consul(lobby_id, {:get, :locks})
    assert locks == [:allyid, :team]

    # Remove a lock
    _tachyon_send(hsocket, %{cmd: "c.lobby.message", message: "$unlock team"})
    locks = Coordinator.call_consul(lobby_id, {:get, :locks})
    assert locks == [:allyid]

    # Add a lock that doesn't exist
    _tachyon_send(hsocket, %{cmd: "c.lobby.message", message: "$lock ptaq"})
    locks = Coordinator.call_consul(lobby_id, {:get, :locks})
    assert locks == [:allyid]

    # Remove a lock not in there
    _tachyon_send(hsocket, %{cmd: "c.lobby.message", message: "$unlock team"})
    locks = Coordinator.call_consul(lobby_id, {:get, :locks})
    assert locks == [:allyid]

    # Remove a lock that doesn't exist
    _tachyon_send(hsocket, %{cmd: "c.lobby.message", message: "$unlock damgam"})
    locks = Coordinator.call_consul(lobby_id, {:get, :locks})
    assert locks == [:allyid]

    # Lock nothing
    _tachyon_send(hsocket, %{cmd: "c.lobby.message", message: "$lock"})
    locks = Coordinator.call_consul(lobby_id, {:get, :locks})
    assert locks == [:allyid]

    # Unlock nothing
    _tachyon_send(hsocket, %{cmd: "c.lobby.message", message: "$lock"})
    locks = Coordinator.call_consul(lobby_id, {:get, :locks})
    assert locks == [:allyid]
  end

  test "team_number", %{player: player, hsocket: hsocket, psocket: psocket, lobby_id: lobby_id} do
    # Try to change team
    _tachyon_send(psocket, %{cmd: "c.lobby.update_status", client: %{team_number: 1}})
    assert Client.get_client_by_id(player.id).team_number == 1

    _tachyon_send(psocket, %{cmd: "c.lobby.update_status", client: %{team_number: 2}})
    assert Client.get_client_by_id(player.id).team_number == 2

    _tachyon_send(hsocket, %{cmd: "c.lobby.message", message: "$lock team"})
    assert Coordinator.call_consul(lobby_id, {:get, :locks}) == [:team]

    # Lock team and try to change it
    _tachyon_send(psocket, %{cmd: "c.lobby.update_status", client: %{team_number: 1}})
    assert Client.get_client_by_id(player.id).team_number == 2

    # Unlock and change
    _tachyon_send(hsocket, %{cmd: "c.lobby.message", message: "$unlock team"})
    _tachyon_send(psocket, %{cmd: "c.lobby.update_status", client: %{team_number: 1}})
    assert Client.get_client_by_id(player.id).team_number == 1
  end

  test "player_number", %{player: player, hsocket: hsocket, psocket: psocket, lobby_id: lobby_id} do
    # Try to change team
    _tachyon_send(psocket, %{cmd: "c.lobby.update_status", client: %{player_number: 1}})
    assert Client.get_client_by_id(player.id).player_number == 1

    _tachyon_send(psocket, %{cmd: "c.lobby.update_status", client: %{player_number: 2}})
    assert Client.get_client_by_id(player.id).player_number == 2

    _tachyon_send(hsocket, %{cmd: "c.lobby.message", message: "$lock allyid"})
    assert Coordinator.call_consul(lobby_id, {:get, :locks}) == [:allyid]

    # Lock team and try to change it
    _tachyon_send(psocket, %{cmd: "c.lobby.update_status", client: %{player_number: 1}})
    assert Client.get_client_by_id(player.id).player_number == 2

    # Unlock and change
    _tachyon_send(hsocket, %{cmd: "c.lobby.message", message: "$unlock allyid"})
    _tachyon_send(psocket, %{cmd: "c.lobby.update_status", client: %{player_number: 1}})
    assert Client.get_client_by_id(player.id).player_number == 1
  end

  test "player", %{player: player, hsocket: hsocket, psocket: psocket, lobby_id: lobby_id} do
    # Try to change team
    _tachyon_send(psocket, %{cmd: "c.lobby.update_status", client: %{player: true}})
    assert Client.get_client_by_id(player.id).player == true

    _tachyon_send(psocket, %{cmd: "c.lobby.update_status", client: %{player: false}})
    assert Client.get_client_by_id(player.id).player == false

    _tachyon_send(hsocket, %{cmd: "c.lobby.message", message: "$lock player"})
    assert Coordinator.call_consul(lobby_id, {:get, :locks}) == [:player]

    # Lock team and try to change it
    _tachyon_send(psocket, %{cmd: "c.lobby.update_status", client: %{player: true}})
    assert Client.get_client_by_id(player.id).player == false

    # Unlock and change
    _tachyon_send(hsocket, %{cmd: "c.lobby.message", message: "$unlock player"})
    _tachyon_send(psocket, %{cmd: "c.lobby.update_status", client: %{player: true}})
    assert Client.get_client_by_id(player.id).player == true
  end

  test "spectator", %{player: player, hsocket: hsocket, psocket: psocket, lobby_id: lobby_id} do
    # Try to change team
    _tachyon_send(psocket, %{cmd: "c.lobby.update_status", client: %{player: false}})
    assert Client.get_client_by_id(player.id).player == false

    _tachyon_send(psocket, %{cmd: "c.lobby.update_status", client: %{player: true}})
    assert Client.get_client_by_id(player.id).player == true

    _tachyon_send(hsocket, %{cmd: "c.lobby.message", message: "$lock spectator"})
    assert Coordinator.call_consul(lobby_id, {:get, :locks}) == [:spectator]

    # Lock team and try to change it
    _tachyon_send(psocket, %{cmd: "c.lobby.update_status", client: %{player: false}})
    assert Client.get_client_by_id(player.id).player == true

    # Unlock and change
    _tachyon_send(hsocket, %{cmd: "c.lobby.message", message: "$unlock spectator"})
    _tachyon_send(psocket, %{cmd: "c.lobby.update_status", client: %{player: false}})
    assert Client.get_client_by_id(player.id).player == false
  end
end
