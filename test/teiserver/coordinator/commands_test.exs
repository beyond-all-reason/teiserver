defmodule Teiserver.Coordinator.CommandsTest do
  use Central.ServerCase, async: false
  alias Teiserver.Battle.Lobby
  alias Teiserver.Common.PubsubListener
  alias Teiserver.{User, Client, Coordinator, Account}

  import Teiserver.TeiserverTestLib,
    only: [tachyon_auth_setup: 0, _tachyon_send: 2, _tachyon_recv: 1]

  setup do
    Coordinator.start_coordinator()
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
    [reply] = _tachyon_recv(hsocket)
    lobby_id = reply["lobby"]["id"]

    listener = PubsubListener.new_listener(["legacy_battle_updates:#{lobby_id}"])

    # Player needs to be added to the battle
    Lobby.add_user_to_battle(player.id, lobby_id, "script_password")
    player_client = Client.get_client_by_id(player.id)
    Client.update(%{player_client |
      player: true
    }, :client_updated_battlestatus)

    # Add user message
    _tachyon_recv(hsocket)

    # Battlestatus message
    _tachyon_recv(hsocket)

    {:ok, hsocket: hsocket, psocket: psocket, host: host, player: player, lobby_id: lobby_id, listener: listener}
  end

  test "specunready", %{lobby_id: lobby_id, player: player1, hsocket: hsocket} do
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

    data = %{cmd: "c.lobby.message", message: "$specunready"}
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

  test "makeready", %{lobby_id: lobby_id, player: player1, hsocket: hsocket} do
    %{user: player2} = tachyon_auth_setup()

    # Add player2 to the battle but as a spectator
    Lobby.add_user_to_battle(player2.id, lobby_id, "script_password")
    player_client = Client.get_client_by_id(player2.id)
    Client.update(%{player_client |
      player: true,
      ready: false
    }, :client_updated_battlestatus)

    readies = Lobby.get_battle!(lobby_id)
    |> Map.get(:players)
    |> Enum.map(fn userid -> Client.get_client_by_id(userid) |> Map.get(:ready) end)

    assert readies == [false, false]

    data = %{cmd: "c.lobby.message", message: "$makeready"}
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
    data = %{cmd: "c.lobby.message", message: "$makeready ##{player1.id}"}
    _tachyon_send(hsocket, data)

    readies = Lobby.get_battle!(lobby_id)
    |> Map.get(:players)
    |> Enum.map(fn userid -> Client.get_client_by_id(userid) |> Map.get(:ready) end)

    assert readies == [false, true]
  end

  test "pull user", %{lobby_id: lobby_id, hsocket: hsocket} do
    %{user: player2, socket: psocket} = tachyon_auth_setup()

    data = %{cmd: "c.lobby.message", message: "$pull ##{player2.id}"}
    _tachyon_send(hsocket, data)

    [reply] = _tachyon_recv(psocket)
    assert reply["cmd"] == "s.lobby.force_join"
    assert reply["lobby"]["id"] == lobby_id
  end

  # TODO: settag
  # TODO: modwarn

  test "leveltoplay", %{lobby_id: lobby_id, hsocket: hsocket} do
    setting = Coordinator.call_consul(lobby_id, {:get, :level_to_play})
    assert setting == 0

    data = %{cmd: "c.lobby.message", message: "$leveltoplay 3"}
    _tachyon_send(hsocket, data)
    :timer.sleep(500)

    setting = Coordinator.call_consul(lobby_id, {:get, :level_to_play})
    assert setting == 3

    data = %{cmd: "c.lobby.message", message: "$leveltoplay Xy"}
    _tachyon_send(hsocket, data)
    :timer.sleep(500)

    setting = Coordinator.call_consul(lobby_id, {:get, :level_to_play})
    assert setting == 3
  end

  test "leveltospectate", %{lobby_id: lobby_id, hsocket: hsocket} do
    setting = Coordinator.call_consul(lobby_id, {:get, :level_to_spectate})
    assert setting == 0

    data = %{cmd: "c.lobby.message", message: "$leveltospectate 3"}
    _tachyon_send(hsocket, data)
    :timer.sleep(500)

    setting = Coordinator.call_consul(lobby_id, {:get, :level_to_spectate})
    assert setting == 3

    data = %{cmd: "c.lobby.message", message: "$leveltospectate Xy"}
    _tachyon_send(hsocket, data)
    :timer.sleep(500)

    setting = Coordinator.call_consul(lobby_id, {:get, :level_to_spectate})
    assert setting == 3
  end

  # Broken since we now propogate the action via the hook server which breaks in tests
  test "modban", %{lobby_id: lobby_id, host: host, hsocket: hsocket, player: player, listener: listener} do
    assert User.is_muted?(player.id) == false
    assert User.is_banned?(player.id) == false

    hook_listener = PubsubListener.new_listener(["account_hooks"])

    data = %{cmd: "c.lobby.message", message: "$modban #{player.name} 60 Spamming channel"}
    _tachyon_send(hsocket, data)
    :timer.sleep(500)

    hook_message = PubsubListener.get(hook_listener) |> hd
    {:account_hooks, :create_report, report} = hook_message

    # Ensure the report was created
    assert Account.get_report!(report.id)

    messages = PubsubListener.get(listener)
    assert messages == [{:battle_updated, lobby_id, {Coordinator.get_coordinator_userid(), "#{player.name} banned for 60 hours by #{host.name}, reason: Spamming channel", lobby_id}, :say}]

    # Now propogate the broadcast the way the hook server would have
    User.update_report(report.id)

    assert User.is_muted?(player.id) == false
    assert User.is_banned?(player.id) == true
  end

  test "modmute", %{lobby_id: lobby_id, host: host, hsocket: hsocket, player: player, listener: listener} do
    assert User.is_muted?(player.id) == false
    assert User.is_banned?(player.id) == false

    hook_listener = PubsubListener.new_listener(["account_hooks"])

    data = %{cmd: "c.lobby.message", message: "$modmute #{player.name} 60 Spamming channel"}
    _tachyon_send(hsocket, data)
    :timer.sleep(500)

    hook_message = PubsubListener.get(hook_listener) |> hd
    {:account_hooks, :create_report, report} = hook_message

    # Ensure the report was created
    assert Account.get_report!(report.id)

    messages = PubsubListener.get(listener)
    assert messages == [{:battle_updated, lobby_id, {Coordinator.get_coordinator_userid(), "#{player.name} muted for 60 hours by #{host.name}, reason: Spamming channel", lobby_id}, :say}]

    # Now propogate the broadcast the way the hook server would have
    User.update_report(report.id)

    assert User.is_muted?(player.id) == true
    assert User.is_banned?(player.id) == false
  end

  test "timeout", %{host: host, player: player, hsocket: hsocket, lobby_id: lobby_id} do
    player_client = Client.get_client_by_id(player.id)
    assert player_client.player == true

    data = %{cmd: "c.lobby.message", message: "$timeout #{player.name} Because I said so"}
    _tachyon_send(hsocket, data)

    player_client = Client.get_client_by_id(player.id)
    assert player_client.lobby_id == nil

    # Check ban state (we added this after bans, don't want to get them confused)
    bans = Coordinator.call_consul(lobby_id, {:get, :bans})
    assert bans == %{}

    # Check timeout state
    timeouts = Coordinator.call_consul(lobby_id, {:get, :timeouts})
    assert timeouts == %{player.id => %{by: host.id, level: :banned, reason: "Because I said so"}}
  end

  test "kick by name", %{player: player, hsocket: hsocket, lobby_id: lobby_id} do
    player_client = Client.get_client_by_id(player.id)
    assert player_client.player == true

    data = %{cmd: "c.lobby.message", message: "$lobbykick #{player.name}"}
    _tachyon_send(hsocket, data)

    player_client = Client.get_client_by_id(player.id)
    assert player_client.lobby_id == nil

    # Check ban state
    bans = Coordinator.call_consul(lobby_id, {:get, :bans})
    assert bans == %{}
  end

  test "ban by name", %{host: host, player: player, hsocket: hsocket, lobby_id: lobby_id} do
    player_client = Client.get_client_by_id(player.id)
    assert player_client.player == true

    data = %{cmd: "c.lobby.message", message: "$lobbyban #{player.name} Because I said so"}
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

    data = %{cmd: "c.lobby.message", message: "$lobbyban #{player.name |> String.slice(0, 17)}"}
    _tachyon_send(hsocket, data)

    player_client = Client.get_client_by_id(player.id)
    assert player_client.lobby_id == nil

    # Check ban state
    bans = Coordinator.call_consul(lobby_id, {:get, :bans})
    assert bans == %{player.id => %{by: host.id, level: :banned, reason: "Banned"}}
  end

  test "error with no name", %{player: player, hsocket: hsocket, lobby_id: lobby_id} do
    player_client = Client.get_client_by_id(player.id)
    assert player_client.player == true

    data = %{cmd: "c.lobby.message", message: "$kick noname"}
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

    data = %{cmd: "c.lobby.message", message: "$lobbybanmult #{player1.name} #{player2.name} #{player3.name} no_player_of_this_name"}
    _tachyon_send(hsocket, data)

    player1_client = Client.get_client_by_id(player1.id)
    player2_client = Client.get_client_by_id(player2.id)
    assert player1_client.lobby_id == nil
    assert player2_client.lobby_id == nil

    # Check ban state
    bans = Coordinator.call_consul(lobby_id, {:get, :bans})
    assert bans == %{
      player1.id => %{by: host.id, level: :banned, reason: "Banned"},
      player2.id => %{by: host.id, level: :banned, reason: "Banned"},
      player3.id => %{by: host.id, level: :banned, reason: "Banned"},
    }

    # Now unban player 3
    data = %{cmd: "c.lobby.message", message: "$unban #{player3.name}"}
    _tachyon_send(hsocket, data)

    bans = Coordinator.call_consul(lobby_id, {:get, :bans})
    assert bans == %{
      player1.id => %{by: host.id, level: :banned, reason: "Banned"},
      player2.id => %{by: host.id, level: :banned, reason: "Banned"}
    }

    # Now test it with a reason given
    data = %{cmd: "c.lobby.message", message: "$lobbybanmult #{player1.name} #{player2.name} #{player3.name} no_player_of_this_name !! Reason given is xyz"}
    _tachyon_send(hsocket, data)


    bans = Coordinator.call_consul(lobby_id, {:get, :bans})
    assert bans == %{
      player1.id => %{by: host.id, level: :banned, reason: "Reason given is xyz"},
      player2.id => %{by: host.id, level: :banned, reason: "Reason given is xyz"},
      player3.id => %{by: host.id, level: :banned, reason: "Reason given is xyz"},
    }
  end

  test "set_player_limit", %{lobby_id: lobby_id, hsocket: hsocket, host: host} do
    player_limit = Coordinator.call_consul(lobby_id, {:get, :player_limit})
    assert player_limit == 20

    data = %{cmd: "c.lobby.message", message: "$playerlimit 16"}
    _tachyon_send(hsocket, data)

    [reply] = _tachyon_recv(hsocket)
    assert reply == %{
      "cmd" => "s.lobby.say",
      "lobby_id" => lobby_id,
      "message" => "$playerlimit 16",
      "sender" => host.id
    }

    # Check state
    player_limit = Coordinator.call_consul(lobby_id, {:get, :player_limit})
    assert player_limit == 16
  end

  test "status", %{lobby_id: lobby_id, hsocket: hsocket} do
    data = %{cmd: "c.lobby.message", message: "$status"}
    _tachyon_send(hsocket, data)

    [reply] = _tachyon_recv(hsocket)
    assert reply["cmd"] == "s.communication.received_direct_message"
    assert reply["sender_id"] == Coordinator.get_coordinator_userid()
    assert reply["message"] |> Enum.slice(0, 4) == ["Status for battle ##{lobby_id}", "Locks: ", "Gatekeeper: default", "Join queue: "]
  end

  test "help", %{lobby_id: lobby_id, hsocket: hsocket, host: host} do
    data = %{cmd: "c.lobby.message", message: "$help"}
    _tachyon_send(hsocket, data)

    [reply] = _tachyon_recv(hsocket)
    assert reply == %{"cmd" => "s.lobby.say", "lobby_id" => lobby_id, "message" => "$help", "sender" => host.id}

    [reply] = _tachyon_recv(hsocket)
    assert reply["cmd"] == "s.communication.received_direct_message"
    assert reply["sender_id"] == Coordinator.get_coordinator_userid()
    assert reply["message"] |> Enum.count > 5
  end

  test "passthrough", %{hsocket: hsocket, listener: listener} do
    data = %{cmd: "c.lobby.message", message: "$non-existing command"}
    _tachyon_send(hsocket, data)
    messages = PubsubListener.get(listener)
    assert messages == []

    reply = _tachyon_recv(hsocket)
    assert reply == [%{"cmd" => "s.lobby.received_lobby_direct_announce", "message" => "No command of that name", "sender_id" => Coordinator.get_coordinator_userid()}]
  end

  test "join_queue", %{lobby_id: lobby_id, hsocket: hsocket, psocket: _psocket, player: player} do
    # We don't want to use the player we start with, we want to number our players specifically
    Lobby.remove_user_from_any_battle(player.id)
    _tachyon_send(hsocket, %{cmd: "c.lobby_host.update_host_status", boss: nil, teamsize: 8, teamcount: 2})

    # At the moment we are hard coding the join queue to 8v8s until we
    # add something to get the player count limit
    ps1 = tachyon_auth_setup()
    ps2 = tachyon_auth_setup()
    ps3 = tachyon_auth_setup()
    ps4 = tachyon_auth_setup()
    ps5 = tachyon_auth_setup()
    ps6 = tachyon_auth_setup()
    ps7 = tachyon_auth_setup()
    ps8 = tachyon_auth_setup()
    ps9 = tachyon_auth_setup()
    ps10 = tachyon_auth_setup()
    ps11 = tachyon_auth_setup()
    ps12 = tachyon_auth_setup()
    ps13 = tachyon_auth_setup()
    ps14 = tachyon_auth_setup()
    ps15 = tachyon_auth_setup()
    ps16 = tachyon_auth_setup()

    %{user: player17, socket: socket17} = tachyon_auth_setup()
    %{user: player18, socket: socket18} = tachyon_auth_setup()
    %{user: player19, socket: socket19} = tachyon_auth_setup()

    [ps1, ps2, ps3, ps4, ps5, ps6, ps7, ps8, ps9, ps10, ps11, ps12, ps13, ps14, ps15, ps16]
    |> Enum.each(fn %{user: user, socket: socket} ->
      Lobby.force_add_user_to_battle(user.id, lobby_id)
      _tachyon_send(socket, %{cmd: "c.lobby.update_status", player: true, ready: true})
    end)

    Lobby.force_add_user_to_battle(player17.id, lobby_id)
    Lobby.force_add_user_to_battle(player18.id, lobby_id)
    Lobby.force_add_user_to_battle(player19.id, lobby_id)

    queue = Coordinator.call_consul(lobby_id, {:get, :join_queue})
    assert queue == []

    # # Add to the queue
    _tachyon_send(socket17, %{cmd: "c.lobby.message", message: "$joinq"})
    _tachyon_send(socket18, %{cmd: "c.lobby.message", message: "$joinq"})
    _tachyon_send(socket19, %{cmd: "c.lobby.message", message: "$joinq"})

    queue = Coordinator.call_consul(lobby_id, {:get, :join_queue})
    assert queue == [player17.id, player18.id, player19.id]

    # Now leave the queue
    _tachyon_send(socket18, %{cmd: "c.lobby.message", message: "$leaveq"})
    queue = Coordinator.call_consul(lobby_id, {:get, :join_queue})
    assert queue == [player17.id, player19.id]

    # And the battle
    _tachyon_send(socket19, %{cmd: "c.lobby.leave"})
    queue = Coordinator.call_consul(lobby_id, {:get, :join_queue})
    assert queue == [player17.id]

    # Now we need one of the players to become a spectator and open up a slot!
    assert Client.get_client_by_id(player17.id).player == false
    _tachyon_send(ps1.socket, %{cmd: "c.lobby.update_status", player: false})

    :timer.sleep(50)

    assert Client.get_client_by_id(player17.id).player == true
    queue = Coordinator.call_consul(lobby_id, {:get, :join_queue})
    assert queue == []

    # Now get users 18 and 19 back in
    Lobby.force_add_user_to_battle(player18.id, lobby_id)
    Lobby.force_add_user_to_battle(player19.id, lobby_id)

    # Joinq again
    _tachyon_send(socket17, %{cmd: "c.lobby.message", message: "$joinq"})
    _tachyon_send(socket18, %{cmd: "c.lobby.message", message: "$joinq"})
    _tachyon_send(socket19, %{cmd: "c.lobby.message", message: "$joinq"})

    queue = Coordinator.call_consul(lobby_id, {:get, :join_queue})
    assert queue == [player18.id, player19.id]

    # Now make player18 a player
    _tachyon_send(socket18, %{cmd: "c.lobby.update_status", player: true, ready: true})

    # Queue won't update yet, only does so when a player leaves
    queue = Coordinator.call_consul(lobby_id, {:get, :join_queue})
    assert queue == [player18.id, player19.id]

    # Call the tick function, 18 is now a player so should be removed from the queue
    Coordinator.cast_consul(lobby_id, :tick)

    queue = Coordinator.call_consul(lobby_id, {:get, :join_queue})
    assert queue == [player19.id]
  end
end
