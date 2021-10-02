defmodule Teiserver.SpringMatchmakingTest do
  use Central.ServerCase, async: false
  require Logger
  alias Teiserver.{Client, Game}
  alias Teiserver.Battle.Lobby
  alias Teiserver.Data.Matchmaking
  import Central.Helpers.NumberHelper, only: [int_parse: 1]

  import Teiserver.TeiserverTestLib,
    only: [auth_setup: 0, _send_raw: 2, _recv_raw: 1, _recv_until: 1]

  setup do
    Teiserver.Coordinator.start_coordinator()
    %{socket: socket, user: user} = auth_setup()
    {:ok, socket: socket, user: user}
  end

  test "queue lifecycle", %{socket: socket1, user: user1} do
    {:ok, queue} =
      Game.create_queue(%{
        "name" => "test_queue",
        "team_size" => 1,
        "icon" => "far fa-home",
        "colour" => "#112233",
        "map_list" => ["map1"],
        "conditions" => %{},
        "settings" => %{
          "tick_interval" => 60_000
        }
      })

    queue = Matchmaking.get_queue(queue.id)

    %{socket: socket2, user: user2} = auth_setup()
    %{socket: socket3, user: user3} = auth_setup()
    %{socket: battle_socket, user: _host_user} = auth_setup()

    # Clear both sockets
    _recv_raw(socket1)
    _recv_raw(socket2)
    _recv_raw(socket3)

    # Join the queue
    _send_raw(socket1, "c.matchmaking.join_queue #{queue.id}\n")
    reply = _recv_raw(socket1)
    assert reply == "OK cmd=c.matchmaking.join_queue\t#{queue.id}\n"

    # Trigger the queue server and see if anything happens
    send(Matchmaking.get_queue_pid(queue.id), :tick)
    reply = _recv_raw(socket1)
    assert reply == :timeout

    # Now get the second user to join
    _send_raw(socket2, "c.matchmaking.join_queue #{queue.id}\n")
    reply = _recv_raw(socket2)
    assert reply =~ "OK cmd=c.matchmaking.join_queue\t#{queue.id}\n"

    # Check server state
    state = GenServer.call(Matchmaking.get_queue_pid(queue.id), :get_state)
    assert state.unmatched_players == [user2.id, user1.id]
    assert state.matched_players == []
    assert state.players_accepted == []

    # 3rd user to join, won't be playing the battle
    _send_raw(socket3, "c.matchmaking.join_queue #{queue.id}\n")
    reply = _recv_raw(socket3)
    assert reply =~ "OK cmd=c.matchmaking.join_queue\t#{queue.id}\n"

    # Check server state
    state = GenServer.call(Matchmaking.get_queue_pid(queue.id), :get_state)
    assert state.unmatched_players == [user3.id, user2.id, user1.id]
    assert state.matched_players == []
    assert state.players_accepted == []

    # Tick, we expect to be send a pair of ready checks
    send(Matchmaking.get_queue_pid(queue.id), :tick)
    reply = _recv_raw(socket1)
    assert reply == "s.matchmaking.ready_check #{queue.id}\n"
    reply = _recv_raw(socket2)
    assert reply == "s.matchmaking.ready_check #{queue.id}\n"
    reply = _recv_raw(socket3)
    assert reply == :timeout

    # Accept the first
    _send_raw(socket1, "c.matchmaking.ready\n")
    reply = _recv_raw(socket1)
    assert reply == :timeout

    # Lets see what the state of the queue_server is
    state = GenServer.call(Matchmaking.get_queue_pid(queue.id), :get_state)
    assert state.finding_battle == false
    assert state.unmatched_players == [user3.id]
    assert state.matched_players == [user1.id, user2.id]
    assert state.players_accepted == [user1.id]
    assert state.waiting_for_players == [user2.id]

    # And the second
    _send_raw(socket2, "c.matchmaking.ready\n")
    reply = _recv_raw(socket2)
    assert reply == :timeout

    state = GenServer.call(Matchmaking.get_queue_pid(queue.id), :get_state)
    assert state.finding_battle == true
    assert state.unmatched_players == [user3.id]
    assert state.matched_players == [user1.id, user2.id]
    assert state.players_accepted == [user2.id, user1.id]
    assert state.waiting_for_players == []

    # Tick, it shouldn't result in a change since there's no battles open
    send(Matchmaking.get_queue_pid(queue.id), :tick)
    state2 = GenServer.call(Matchmaking.get_queue_pid(queue.id), :get_state)
    assert state == state2

    # Now lets create a battle
    _recv_raw(battle_socket)

    _send_raw(
      battle_socket,
      "OPENBATTLE 0 0 empty 322 16 gameHash 0 mapHash engineName\tengineVersion\tmapName\tgameTitle\tgameName\n"
    )

    # We know the battle is being opened, don't need to worry about it
    _recv_raw(socket1)
    _recv_raw(socket2)

    reply = _recv_raw(battle_socket)
    [_all, lobby_id] = Regex.run(~r/BATTLEOPENED ([0-9]+) [0-9]/, reply)
    lobby_id = int_parse(lobby_id)
    battle = Lobby.get_battle!(lobby_id)
    assert battle != nil

    # Now we have a battle open, tick should matter
    send(Matchmaking.get_queue_pid(queue.id), :tick)
    state = GenServer.call(Matchmaking.get_queue_pid(queue.id), :get_state)
    assert state.finding_battle == false
    assert state.matched_players == []
    assert state.unmatched_players == [user3.id]
    assert state.ready_started_at == nil

    # Commands should be sent to user1 and user2
    reply = _recv_raw(socket1)
    assert reply =~ "JOINBATTLE #{lobby_id} gameHash\n"
    reply = _recv_raw(socket2)
    assert reply =~ "JOINBATTLE #{lobby_id} gameHash\n"

    # :timer.sleep(500)

    # Next up, we are expecting the battle to get setup
    reply = _recv_until(battle_socket)

    # In the middle of the messages will be the client status messages
    # we cannot be sure of their order or exact values so we do their test later
    assert reply =~ "JOINEDBATTLE #{lobby_id} #{user2.name}"
    assert reply =~ "JOINEDBATTLE #{lobby_id} #{user1.name}"
    assert reply =~ "SAIDPRIVATE Coordinator !autobalance off"
    assert reply =~ "SAIDPRIVATE Coordinator !map map1"
    assert reply =~ "SAIDPRIVATE Coordinator !forcestart"

    # Lets make sure the clients got updated
    client1 = Client.get_client_by_id(user1.id)
    client2 = Client.get_client_by_id(user2.id)
    client3 = Client.get_client_by_id(user3.id)

    assert client1.player == true
    assert client2.player == true
    assert client3.player == false

    assert client1.team_number != client2.team_number
    assert client1.ally_team_number != client2.ally_team_number
  end

  test "joining and leaving all queues", %{socket: socket, user: user} do
    {:ok, queue1} =
      Game.create_queue(%{
        "name" => "test_queue_join_leave1",
        "team_size" => 1,
        "icon" => "far fa-home",
        "colour" => "#112233",
        "map_list" => ["map1"],
        "conditions" => %{},
        "settings" => %{
          "tick_interval" => 60_000
        }
      })

    {:ok, queue2} =
      Game.create_queue(%{
        "name" => "test_queue_join_leave2",
        "team_size" => 1,
        "icon" => "far fa-home",
        "colour" => "#112233",
        "map_list" => ["map1"],
        "conditions" => %{},
        "settings" => %{
          "tick_interval" => 60_000
        }
      })

    queue1 = Matchmaking.get_queue(queue1.id)
    queue2 = Matchmaking.get_queue(queue2.id)
    client_pid = Client.get_client_by_id(user.id).pid

    # List the queue
    _send_raw(socket, "c.matchmaking.list_all_queues\n")
    reply = _recv_raw(socket)
    assert reply =~ "s.matchmaking.full_queue_list "
    assert reply =~ "#{queue1.id}:test_queue_join_leave1"
    assert reply =~ "#{queue2.id}:test_queue_join_leave2"

    # List my queues, should be empty
    _send_raw(socket, "c.matchmaking.list_my_queues\n")
    reply = _recv_raw(socket)
    assert reply == "s.matchmaking.your_queue_list \n"

    # Tell me about this queue
    _send_raw(socket, "c.matchmaking.get_queue_info #{queue1.id}\n")
    reply = _recv_raw(socket)
    assert reply == "s.matchmaking.queue_info #{queue1.id}\ttest_queue_join_leave1\t0\t0\n"

    # Join a queue that doesn't exist
    _send_raw(socket, "c.matchmaking.join_queue 0\n")
    reply = _recv_raw(socket)
    assert reply == "NO cmd=c.matchmaking.join_queue\t0\n"

    # Join the queue (just the first player)
    _send_raw(socket, "c.matchmaking.join_queue #{queue1.id}\n")
    reply = _recv_raw(socket)
    assert reply == "OK cmd=c.matchmaking.join_queue\t#{queue1.id}\n"

    # List my queues, should have this one queue
    _send_raw(socket, "c.matchmaking.list_my_queues\n")
    reply = _recv_raw(socket)
    assert reply == "s.matchmaking.your_queue_list #{queue1.id}:test_queue_join_leave1\n"

    # Leave the queue
    _send_raw(socket, "c.matchmaking.leave_queue #{queue1.id}\n")
    reply = _recv_raw(socket)
    assert reply == :timeout

    # List my queues, should be empty
    _send_raw(socket, "c.matchmaking.list_my_queues\n")
    reply = _recv_raw(socket)
    assert reply == "s.matchmaking.your_queue_list \n"

    user_queues = GenServer.call(client_pid, {:get, :queues})
    assert user_queues == []

    # Tell me about this queue, it's different now
    _send_raw(socket, "c.matchmaking.get_queue_info #{queue1.id}\n")
    reply = _recv_raw(socket)
    assert reply == "s.matchmaking.queue_info #{queue1.id}\ttest_queue_join_leave1\t0\t0\n"

    # And rejoin
    _send_raw(socket, "c.matchmaking.join_queue #{queue1.id}\n")
    reply = _recv_raw(socket)
    assert reply == "OK cmd=c.matchmaking.join_queue\t#{queue1.id}\n"

    user_queues = GenServer.call(client_pid, {:get, :queues})
    assert user_queues == [queue1.id]

    # Join queue 2
    _send_raw(socket, "c.matchmaking.join_queue #{queue2.id}\n")
    reply = _recv_raw(socket)
    assert reply == "OK cmd=c.matchmaking.join_queue\t#{queue2.id}\n"

    user_queues = GenServer.call(client_pid, {:get, :queues})
    assert user_queues == [queue2.id, queue1.id]

    # Now leave all queues
    _send_raw(socket, "c.matchmaking.leave_all_queues\n")
    reply = _recv_raw(socket)
    assert reply == :timeout

    user_queues = GenServer.call(client_pid, {:get, :queues})
    assert user_queues == []
  end

  test "decline ready up", %{socket: socket1, user: user1} do
    {:ok, queue} =
      Game.create_queue(%{
        "name" => "test_queue",
        "team_size" => 1,
        "icon" => "far fa-home",
        "colour" => "#112233",
        "map_list" => ["map1"],
        "conditions" => %{},
        "settings" => %{
          "tick_interval" => 60_000
        }
      })

    queue = Matchmaking.get_queue(queue.id)
    %{socket: socket2, user: user2} = auth_setup()

    # Clear both sockets
    _recv_raw(socket1)
    _recv_raw(socket2)

    # Join the queue
    _send_raw(socket1, "c.matchmaking.join_queue #{queue.id}\n")
    reply = _recv_raw(socket1)
    assert reply == "OK cmd=c.matchmaking.join_queue\t#{queue.id}\n"

    # Now get the second user to join
    _send_raw(socket2, "c.matchmaking.join_queue #{queue.id}\n")
    reply = _recv_raw(socket2)
    assert reply =~ "OK cmd=c.matchmaking.join_queue\t#{queue.id}\n"

    # Check server state
    state = GenServer.call(Matchmaking.get_queue_pid(queue.id), :get_state)
    assert state.unmatched_players == [user2.id, user1.id]
    assert state.matched_players == []
    assert state.players_accepted == []

    # Tick, we expect to be send a pair of ready checks
    send(Matchmaking.get_queue_pid(queue.id), :tick)
    reply = _recv_raw(socket1)
    assert reply == "s.matchmaking.ready_check #{queue.id}\n"
    reply = _recv_raw(socket2)
    assert reply == "s.matchmaking.ready_check #{queue.id}\n"

    # Accept the first
    _send_raw(socket1, "c.matchmaking.ready\n")
    reply = _recv_raw(socket1)
    assert reply == :timeout

    # Lets see what the state of the queue_server is
    state = GenServer.call(Matchmaking.get_queue_pid(queue.id), :get_state)
    assert state.finding_battle == false
    assert state.unmatched_players == []
    assert state.matched_players == [user1.id, user2.id]
    assert state.players_accepted == [user1.id]
    assert state.waiting_for_players == [user2.id]

    # And the second gets rejected
    _send_raw(socket2, "c.matchmaking.decline\n")
    reply = _recv_raw(socket2)
    assert reply == :timeout

    state = GenServer.call(Matchmaking.get_queue_pid(queue.id), :get_state)
    assert state.finding_battle == false
    assert state.unmatched_players == [user1.id]
    assert state.matched_players == []
    assert state.players_accepted == []
    assert state.waiting_for_players == []
  end

  test "wait too long - both fail to ready up", %{socket: socket1, user: user1} do
    {:ok, queue} =
      Game.create_queue(%{
        "name" => "test_queue",
        "team_size" => 1,
        "icon" => "far fa-home",
        "colour" => "#112233",
        "map_list" => ["map1"],
        "conditions" => %{},
        "settings" => %{
          "tick_interval" => 60_000,
          "ready_wait_time" => 1
        }
      })

    queue = Matchmaking.get_queue(queue.id)
    %{socket: socket2, user: user2} = auth_setup()

    # Clear both sockets
    _recv_raw(socket1)
    _recv_raw(socket2)

    # Join the queue
    _send_raw(socket1, "c.matchmaking.join_queue #{queue.id}\n")
    reply = _recv_raw(socket1)
    assert reply == "OK cmd=c.matchmaking.join_queue\t#{queue.id}\n"

    # Now get the second user to join
    _send_raw(socket2, "c.matchmaking.join_queue #{queue.id}\n")
    reply = _recv_raw(socket2)
    assert reply =~ "OK cmd=c.matchmaking.join_queue\t#{queue.id}\n"

    # Check server state
    state = GenServer.call(Matchmaking.get_queue_pid(queue.id), :get_state)
    assert state.unmatched_players == [user2.id, user1.id]
    assert state.matched_players == []
    assert state.players_accepted == []

    # Tick, we expect to be send a pair of ready checks
    send(Matchmaking.get_queue_pid(queue.id), :tick)
    reply = _recv_raw(socket1)
    assert reply == "s.matchmaking.ready_check #{queue.id}\n"
    reply = _recv_raw(socket2)
    assert reply == "s.matchmaking.ready_check #{queue.id}\n"

    # Lets see what the state of the queue_server is
    state = GenServer.call(Matchmaking.get_queue_pid(queue.id), :get_state)
    assert state.finding_battle == false
    assert state.unmatched_players == []
    assert state.matched_players == [user1.id, user2.id]
    assert state.players_accepted == []
    assert state.waiting_for_players == [user1.id, user2.id]

    # Wait for 1 second, tick
    # Previously this caused a bug because we never looked at what happened if "time elapsed"
    # was equal to the ready_wait_time
    :timer.sleep(1000)
    send(Matchmaking.get_queue_pid(queue.id), :tick)
    state = GenServer.call(Matchmaking.get_queue_pid(queue.id), :get_state)
    assert state.finding_battle == false
    assert state.unmatched_players == []
    assert state.matched_players == [user1.id, user2.id]
    assert state.players_accepted == []
    assert state.waiting_for_players == [user1.id, user2.id]

    # Now tick again, should take us over
    :timer.sleep(1000)
    send(Matchmaking.get_queue_pid(queue.id), :tick)
    state = GenServer.call(Matchmaking.get_queue_pid(queue.id), :get_state)
    assert state.finding_battle == false
    assert state.unmatched_players == []
    assert state.matched_players == []
    assert state.players_accepted == []
    assert state.waiting_for_players == []
  end

  test "wait too long - one player readied up", %{socket: socket1, user: user1} do
    {:ok, queue} =
      Game.create_queue(%{
        "name" => "test_queue",
        "team_size" => 1,
        "icon" => "far fa-home",
        "colour" => "#112233",
        "map_list" => ["map1"],
        "conditions" => %{},
        "settings" => %{
          "tick_interval" => 60_000,
          "ready_wait_time" => 1
        }
      })

    queue = Matchmaking.get_queue(queue.id)
    %{socket: socket2, user: user2} = auth_setup()

    # Clear both sockets
    _recv_raw(socket1)
    _recv_raw(socket2)

    # Join the queue
    _send_raw(socket1, "c.matchmaking.join_queue #{queue.id}\n")
    reply = _recv_raw(socket1)
    assert reply == "OK cmd=c.matchmaking.join_queue\t#{queue.id}\n"

    # Now get the second user to join
    _send_raw(socket2, "c.matchmaking.join_queue #{queue.id}\n")
    reply = _recv_raw(socket2)
    assert reply =~ "OK cmd=c.matchmaking.join_queue\t#{queue.id}\n"

    # Check server state
    state = GenServer.call(Matchmaking.get_queue_pid(queue.id), :get_state)
    assert state.unmatched_players == [user2.id, user1.id]
    assert state.matched_players == []
    assert state.players_accepted == []

    # Tick, we expect to be send a pair of ready checks
    send(Matchmaking.get_queue_pid(queue.id), :tick)
    reply = _recv_raw(socket1)
    assert reply == "s.matchmaking.ready_check #{queue.id}\n"
    reply = _recv_raw(socket2)
    assert reply == "s.matchmaking.ready_check #{queue.id}\n"

    # Lets see what the state of the queue_server is
    state = GenServer.call(Matchmaking.get_queue_pid(queue.id), :get_state)
    assert state.finding_battle == false
    assert state.unmatched_players == []
    assert state.matched_players == [user1.id, user2.id]
    assert state.players_accepted == []
    assert state.waiting_for_players == [user1.id, user2.id]

    # Accept the first
    _send_raw(socket1, "c.matchmaking.ready\n")
    reply = _recv_raw(socket1)
    assert reply == :timeout

    # Tick us over the limit, the first player should be still in the queue
    # but the 2nd player should be gone
    :timer.sleep(2000)
    send(Matchmaking.get_queue_pid(queue.id), :tick)
    state = GenServer.call(Matchmaking.get_queue_pid(queue.id), :get_state)
    assert state.finding_battle == false
    assert state.unmatched_players == [user1.id]
    assert state.matched_players == []
    assert state.players_accepted == []
    assert state.waiting_for_players == []
  end
end
