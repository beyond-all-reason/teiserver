defmodule Teiserver.Coordinator.HostUpdateTest do
  use Central.ServerCase, async: false
  alias Teiserver.Battle.Lobby
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

    {:ok, hsocket: hsocket, psocket: psocket, host: host, player: player, lobby_id: lobby_id}
  end

  test "Update host data teamSize/teamCount", %{
    hsocket: hsocket,
    psocket: psocket,
    lobby_id: lobby_id
  } do
    # Host can change teamSize
    data = %{cmd: "c.lobby.message", message: "Global setting changed by marseel (teamSize=7)"}
    _tachyon_send(hsocket, data)
    teamSize = Coordinator.call_consul(lobby_id, {:get, :host_teamsize})
    assert teamSize == 7

    # Player cannot change teamSize
    data = %{cmd: "c.lobby.message", message: "Global setting changed by marseel (teamSize=3)"}
    _tachyon_send(psocket, data)
    teamSize = Coordinator.call_consul(lobby_id, {:get, :host_teamsize})
    # Assert not changed
    assert teamSize == 7

    # Host can change teamCount
    data = %{cmd: "c.lobby.message", message: "Global setting changed by marseel (nbTeams=4)"}
    _tachyon_send(hsocket, data)
    teamSize = Coordinator.call_consul(lobby_id, {:get, :host_teamcount})
    assert teamSize == 4

    # Player cannot change teamCount
    data = %{cmd: "c.lobby.message", message: "Global setting changed by marseel (nbTeams=2)"}
    _tachyon_send(psocket, data)
    teamSize = Coordinator.call_consul(lobby_id, {:get, :host_teamcount})
    assert teamSize == 4
  end
end
