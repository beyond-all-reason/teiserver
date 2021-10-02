defmodule Teiserver.Coordinator.CommandsTest do
  use Central.ServerCase, async: false
  alias Teiserver.Battle.Lobby
  alias Teiserver.Common.PubsubListener
  alias Teiserver.{User, Client, Coordinator, Account}

  import Teiserver.TeiserverTestLib,
    only: [tachyon_auth_setup: 0, _tachyon_send: 2, _tachyon_recv: 1]

  setup do
    Teiserver.Coordinator.start_coordinator()
    %{socket: hsocket, user: host} = tachyon_auth_setup()
    %{socket: psocket, user: player} = tachyon_auth_setup()

    # User needs to be a moderator (at this time) to start/stop Coordinator mode
    User.update_user(%{host | moderator: true})
    Client.refresh_client(host.id)

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

    listener = PubsubListener.new_listener(["legacy_battle_updates:#{lobby_id}"])

    # Player needs to be added to the battle
    Lobby.add_user_to_battle(player.id, lobby_id, "script_password")
    player_client = Client.get_client_by_id(player.id)
    Client.update(%{player_client |
      player: true
    }, :client_updated_battlestatus)

    {:ok, hsocket: hsocket, psocket: psocket, host: host, player: player, lobby_id: lobby_id, listener: listener}
  end


  test "splitlobby", %{host: _host, player: _player, hsocket: _hsocket} do

  end

  test "specunready", %{lobby_id: lobby_id, player: player1, host: host, hsocket: hsocket} do
    %{user: player2} = tachyon_auth_setup()

    # Add player2 to the battle but as a spectator
    Lobby.add_user_to_battle(player2.id, lobby_id, "script_password")
    player_client = Client.get_client_by_id(player2.id)
    Client.update(%{player_client |
      player: false,
      ready: false
    }, :client_updated_battlestatus)

    readies = Lobby.get_battle!(lobby_id)
    |> Map.get(:players)
    |> Enum.map(fn userid -> Client.get_client_by_id(userid) |> Map.get(:ready) end)

    assert readies == [false, false]

    data = %{cmd: "c.lobby.message", userid: host.id, message: "$specunready"}
    _tachyon_send(hsocket, data)

    # Now we check they are ready or they're a spectator
    readies = Lobby.get_battle!(lobby_id)
    |> Map.get(:players)
    |> Enum.map(fn userid -> Client.get_client_by_id(userid) end)
    |> Enum.map(fn c -> c.player == false or c.ready == true end)

    assert readies == [true, true]

    # Unready both again
    player_client = Client.get_client_by_id(player1.id)
    Client.update(%{player_client | ready: false}, :client_updated_battlestatus)

    player_client = Client.get_client_by_id(player2.id)
    Client.update(%{player_client | ready: false}, :client_updated_battlestatus)

    readies = Lobby.get_battle!(lobby_id)
    |> Map.get(:players)
    |> Enum.map(fn userid -> Client.get_client_by_id(userid) |> Map.get(:ready) end)

    assert readies == [false, false]
  end

  test "makeready", %{lobby_id: lobby_id, player: player1, host: host, hsocket: hsocket} do
    %{user: player2} = tachyon_auth_setup()

    # Add player2 to the battle but as a spectator
    Lobby.add_user_to_battle(player2.id, lobby_id, "script_password")
    player_client = Client.get_client_by_id(player2.id)
    Client.update(%{player_client |
      player: false,
      ready: false
    }, :client_updated_battlestatus)

    readies = Lobby.get_battle!(lobby_id)
    |> Map.get(:players)
    |> Enum.map(fn userid -> Client.get_client_by_id(userid) |> Map.get(:ready) end)

    assert readies == [false, false]

    data = %{cmd: "c.lobby.message", userid: host.id, message: "$makeready"}
    _tachyon_send(hsocket, data)

    # Now we get the ready statuses
    readies = Lobby.get_battle!(lobby_id)
    |> Map.get(:players)
    |> Enum.map(fn userid -> Client.get_client_by_id(userid) |> Map.get(:ready) end)

    assert readies == [true, true]

    # Unready both again
    player_client = Client.get_client_by_id(player1.id)
    Client.update(%{player_client | ready: false}, :client_updated_battlestatus)

    player_client = Client.get_client_by_id(player2.id)
    Client.update(%{player_client | ready: false}, :client_updated_battlestatus)

    readies = Lobby.get_battle!(lobby_id)
    |> Map.get(:players)
    |> Enum.map(fn userid -> Client.get_client_by_id(userid) |> Map.get(:ready) end)

    assert readies == [false, false]

    # Now make one of them ready
    data = %{cmd: "c.lobby.message", userid: host.id, message: "$makeready ##{player1.id}"}
    _tachyon_send(hsocket, data)

    readies = Lobby.get_battle!(lobby_id)
    |> Map.get(:players)
    |> Enum.map(fn userid -> Client.get_client_by_id(userid) |> Map.get(:ready) end)

    assert readies == [false, true]
  end

  test "pull user", %{lobby_id: lobby_id, host: host, hsocket: hsocket} do
    %{user: player2, socket: psocket} = tachyon_auth_setup()

    data = %{cmd: "c.lobby.message", userid: host.id, message: "$pull ##{player2.id}"}
    _tachyon_send(hsocket, data)

    reply = _tachyon_recv(psocket)
    assert reply["cmd"] == "s.lobby.join_response"
    assert reply["lobby"]["id"] == lobby_id
  end

  # settag
  # modwarn

  # Broken since we now propogate the action via the hook server which breaks in tests
  test "modban", %{lobby_id: lobby_id, host: host, hsocket: hsocket, player: player, listener: listener} do
    assert User.is_muted?(player.id) == false
    assert User.is_banned?(player.id) == false

    hook_listener = PubsubListener.new_listener(["account_hooks"])

    data = %{cmd: "c.lobby.message", userid: host.id, message: "$modban #{player.name} 60 Spamming channel"}
    _tachyon_send(hsocket, data)
    :timer.sleep(500)

    hook_message = PubsubListener.get(hook_listener) |> hd
    %{payload: report_id} = hook_message
    assert hook_message == %Phoenix.Socket.Broadcast{event: "create_report", payload: report_id, topic: "account_hooks"}

    # Ensure the report was created
    assert Account.get_report!(report_id)

    messages = PubsubListener.get(listener)
    assert messages == [{:battle_updated, lobby_id, {Coordinator.get_coordinator_userid(), "#{player.name} banned for 60 hours by #{host.name}, reason: Spamming channel", lobby_id}, :say}]

    # Now propogate the broadcast the way the hook server would have
    User.update_report(report_id)

    assert User.is_muted?(player.id) == false
    assert User.is_banned?(player.id) == true
  end

  test "modmute", %{lobby_id: lobby_id, host: host, hsocket: hsocket, player: player, listener: listener} do
    assert User.is_muted?(player.id) == false
    assert User.is_banned?(player.id) == false

    hook_listener = PubsubListener.new_listener(["account_hooks"])

    data = %{cmd: "c.lobby.message", userid: host.id, message: "$modmute #{player.name} 60 Spamming channel"}
    _tachyon_send(hsocket, data)
    :timer.sleep(500)

    hook_message = PubsubListener.get(hook_listener) |> hd
    %{payload: report_id} = hook_message
    assert hook_message == %Phoenix.Socket.Broadcast{event: "create_report", payload: report_id, topic: "account_hooks"}

    # Ensure the report was created
    assert Account.get_report!(report_id)

    messages = PubsubListener.get(listener)
    assert messages == [{:battle_updated, lobby_id, {Coordinator.get_coordinator_userid(), "#{player.name} muted for 60 hours by #{host.name}, reason: Spamming channel", lobby_id}, :say}]

    # Now propogate the broadcast the way the hook server would have
    User.update_report(report_id)

    assert User.is_muted?(player.id) == true
    assert User.is_banned?(player.id) == false
  end

  test "ban by name", %{host: host, player: player, hsocket: hsocket, lobby_id: lobby_id} do
    player_client = Client.get_client_by_id(player.id)
    assert player_client.player == true

    data = %{cmd: "c.lobby.message", userid: host.id, message: "$lobbyban #{player.name} Because I said so"}
    _tachyon_send(hsocket, data)

    player_client = Client.get_client_by_id(player.id)
    assert player_client.lobby_id == nil

    # Check ban state
    bans = Coordinator.call_consul(lobby_id, {:get, :bans})
    assert bans == %{player.id => %{by: host.id, level: :banned, reason: "Because I said so"}}
  end

  test "ban by partial name", %{host: host, player: player, hsocket: hsocket, lobby_id: lobby_id} do
    player_client = Client.get_client_by_id(player.id)
    assert player_client.player == true

    data = %{cmd: "c.lobby.message", userid: host.id, message: "$lobbyban #{player.name |> String.slice(0, 17)}"}
    _tachyon_send(hsocket, data)

    player_client = Client.get_client_by_id(player.id)
    assert player_client.lobby_id == nil

    # Check ban state
    bans = Coordinator.call_consul(lobby_id, {:get, :bans})
    assert bans == %{player.id => %{by: host.id, level: :banned, reason: "None given"}}
  end

  test "error with no name", %{host: host, player: player, hsocket: hsocket, lobby_id: lobby_id} do
    player_client = Client.get_client_by_id(player.id)
    assert player_client.player == true

    data = %{cmd: "c.lobby.message", userid: host.id, message: "$kick noname"}
    _tachyon_send(hsocket, data)

    # They should not be kicked, we expect no other errors at this stage
    player_client = Client.get_client_by_id(player.id)
    assert player_client.lobby_id == lobby_id
  end

  test "ban multiple", %{host: host, player: player1, hsocket: hsocket, lobby_id: lobby_id} do
    %{user: player2} = tachyon_auth_setup()
    %{user: player3} = tachyon_auth_setup()

    # Add player2 to the battle but not player 3
    Lobby.add_user_to_battle(player2.id, lobby_id, "script_password")

    player1_client = Client.get_client_by_id(player1.id)
    player2_client = Client.get_client_by_id(player2.id)
    assert player1_client.player == true
    assert player1_client.lobby_id == lobby_id
    assert player2_client.lobby_id == lobby_id

    data = %{cmd: "c.lobby.message", userid: host.id, message: "$lobbybanmult #{player1.name} #{player2.name} #{player3.name} no_player_of_this_name"}
    _tachyon_send(hsocket, data)

    player1_client = Client.get_client_by_id(player1.id)
    player2_client = Client.get_client_by_id(player2.id)
    assert player1_client.lobby_id == nil
    assert player2_client.lobby_id == nil

    # Check ban state
    bans = Coordinator.call_consul(lobby_id, {:get, :bans})
    assert bans == %{
      player1.id => %{by: host.id, level: :banned, reason: "None given"},
      player2.id => %{by: host.id, level: :banned, reason: "None given"},
      player3.id => %{by: host.id, level: :banned, reason: "None given"},
    }

    # Now unban player 3
    data = %{cmd: "c.lobby.message", userid: host.id, message: "$unban #{player3.name}"}
    _tachyon_send(hsocket, data)

    bans = Coordinator.call_consul(lobby_id, {:get, :bans})
    assert bans == %{
      player1.id => %{by: host.id, level: :banned, reason: "None given"},
      player2.id => %{by: host.id, level: :banned, reason: "None given"}
    }
  end

  test "status", %{lobby_id: lobby_id, host: host, hsocket: hsocket} do
    data = %{cmd: "c.lobby.message", userid: host.id, message: "$status"}
    _tachyon_send(hsocket, data)

    reply = _tachyon_recv(hsocket)
    assert reply["cmd"] == "s.communication.direct_message"
    assert reply["sender"] == Coordinator.get_coordinator_userid()
    assert reply["message"] == ["Status for battle ##{lobby_id}", "Gatekeeper: default"]
  end

  test "help", %{host: host, hsocket: hsocket} do
    data = %{cmd: "c.lobby.message", userid: host.id, message: "$help"}
    _tachyon_send(hsocket, data)

    reply = _tachyon_recv(hsocket)
    assert reply["cmd"] == "s.communication.direct_message"
    assert reply["sender"] == Coordinator.get_coordinator_userid()
    assert reply["message"] == ["Command list can currently be found at https://github.com/beyond-all-reason/teiserver/blob/master/lib/teiserver/coordinator/coordinator_lib.ex"]
  end

  test "test passthrough", %{lobby_id: lobby_id, host: host, hsocket: hsocket, listener: listener} do
    data = %{cmd: "c.lobby.message", userid: host.id, message: "$non-existing command"}
    _tachyon_send(hsocket, data)

    messages = PubsubListener.get(listener)
    assert messages == [{:battle_updated, lobby_id, {host.id, "$non-existing command", lobby_id}, :say}]

    reply = _tachyon_recv(hsocket)
    assert reply == :timeout
  end
end
