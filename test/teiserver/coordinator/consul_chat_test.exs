defmodule Teiserver.Coordinator.ConsulChatTest do
  use Central.ServerCase, async: false
  alias Teiserver.Account.ClientLib
  alias Teiserver.{User, Client, Coordinator, Lobby}

  import Teiserver.TeiserverTestLib,
    only: [tachyon_auth_setup: 0, _tachyon_send: 2, _tachyon_recv: 1]

  setup do
    Coordinator.start_coordinator()
    %{socket: hsocket, user: host} = tachyon_auth_setup()
    %{socket: psocket, user: player} = tachyon_auth_setup()

    # User needs to be a moderator (at this time) to start/stop Coordinator mode
    User.update_user(%{host | moderator: true})
    ClientLib.refresh_client(host.id)

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
    [reply] = _tachyon_recv(hsocket)
    lobby_id = reply["lobby"]["id"]

    # Player needs to be added to the battle
    Lobby.force_add_user_to_lobby(player.id, lobby_id)
    player_client = Client.get_client_by_id(player.id)

    Client.update(
      %{player_client | player: true},
      :client_updated_battlestatus
    )

    # Add user message
    _tachyon_recv(hsocket)

    # Battlestatus message
    _tachyon_recv(hsocket)

    # We set a welcome message because if the consul crashes it will reset the welcome-message
    # also, if a function doesn't return a map then the state will no longer be a map
    _tachyon_send(hsocket, %{
      cmd: "c.lobby.message",
      message: "$welcome-message This is the welcome message"
    })

    message = Coordinator.call_consul(lobby_id, {:get, :welcome_message})
    assert message == "This is the welcome message"

    {:ok, hsocket: hsocket, psocket: psocket, host: host, player: player, lobby_id: lobby_id}
  end

  test "standard messages", %{lobby_id: lobby_id, psocket: psocket} do
    data = %{cmd: "c.lobby.message", message: "Chat chat chat 1"}
    _tachyon_send(psocket, data)

    data = %{cmd: "c.lobby.message", message: "Chat chat chat 2"}
    _tachyon_send(psocket, data)

    data = %{cmd: "c.lobby.message", message: "Chat chat chat 3"}
    _tachyon_send(psocket, data)

    message = Coordinator.call_consul(lobby_id, {:get, :welcome_message})
    assert message == "This is the welcome message"
  end

  test "ring flood", %{lobby_id: lobby_id, player: player1, psocket: psocket} do
    data = %{cmd: "c.lobby.message", message: "!ring other_player"}
    _tachyon_send(psocket, data)

    data = %{cmd: "c.lobby.message", message: "!ring other_player"}
    _tachyon_send(psocket, data)

    data = %{cmd: "c.lobby.message", message: "!ring other_player"}
    _tachyon_send(psocket, data)

    timestamps = Coordinator.call_consul(lobby_id, {:get, :ring_timestamps})
    player1_stamps = timestamps[player1.id]
    assert Enum.count(player1_stamps) == 3

    data = %{cmd: "c.lobby.message", message: "!ring other_player"}
    _tachyon_send(psocket, data)

    timestamps = Coordinator.call_consul(lobby_id, {:get, :ring_timestamps})
    player1_stamps = timestamps[player1.id]
    assert Enum.count(player1_stamps) == 4

    flood_count = Central.cache_get(:teiserver_login_count, player1.id)
    assert flood_count == 1

    data = %{cmd: "c.lobby.message", message: "!ring other_player"}
    _tachyon_send(psocket, data)

    timestamps = Coordinator.call_consul(lobby_id, {:get, :ring_timestamps})
    player1_stamps = timestamps[player1.id]
    assert Enum.count(player1_stamps) == 5

    flood_count = Central.cache_get(:teiserver_login_count, player1.id)
    assert flood_count > 1

    message = Coordinator.call_consul(lobby_id, {:get, :welcome_message})
    assert message == "This is the welcome message"
  end
end
