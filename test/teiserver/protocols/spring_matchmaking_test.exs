defmodule Teiserver.SpringMatchmakingTest do
  use Central.ServerCase, async: false
  require Logger
  alias Teiserver.Game
  alias Teiserver.Data.Matchmaking
  import Central.Helpers.NumberHelper, only: [int_parse: 1]

  import Teiserver.TestLib,
    only: [auth_setup: 0, _send: 2, _recv: 1]

  setup do
    %{socket: socket, user: user} = auth_setup()
    {:ok, socket: socket, user: user}
  end

  test "Test queuing", %{socket: socket1, user: user1} do
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
    %{socket: battle_socket} = auth_setup()

    # Clear both sockets
    _recv(socket1)
    _recv(socket2)

    # List the queue
    _send(socket1, "c.matchmaking.list_all_queues\n")
    reply = _recv(socket1)
    assert reply == "s.matchmaking.full_queue_list #{queue.id}:test_queue\n"

    _send(socket2, "c.matchmaking.list_all_queues\n")
    reply = _recv(socket2)
    assert reply == "s.matchmaking.full_queue_list #{queue.id}:test_queue\n"

    # List my queues, should be empty
    _send(socket1, "c.matchmaking.list_my_queues\n")
    reply = _recv(socket1)
    assert reply == "s.matchmaking.your_queue_list \n"

    # Tell me about this queue
    _send(socket1, "c.matchmaking.get_queue_info #{queue.id}\n")
    reply = _recv(socket1)
    assert reply == "s.matchmaking.queue_info #{queue.id}\ttest_queue\t0\t0\n"

    # Join a queue that doesn't exist
    _send(socket1, "c.matchmaking.join_queue 0\n")
    reply = _recv(socket1)
    assert reply == "NO cmd=c.matchmaking.join_queue\t0\n"

    # Join the queue (just the first player)
    _send(socket1, "c.matchmaking.join_queue #{queue.id}\n")
    reply = _recv(socket1)
    assert reply == "OK cmd=c.matchmaking.join_queue\t#{queue.id}\n"

    # List my queues, should have this one queue
    _send(socket1, "c.matchmaking.list_my_queues\n")
    reply = _recv(socket1)
    assert reply == "s.matchmaking.your_queue_list #{queue.id}:test_queue\n"

    # Leave the queue
    _send(socket1, "c.matchmaking.leave_queue #{queue.id}\n")
    reply = _recv(socket1)
    assert reply == :timeout

    # List my queues, should be empty
    _send(socket1, "c.matchmaking.list_my_queues\n")
    reply = _recv(socket1)
    assert reply == "s.matchmaking.your_queue_list \n"

    # Tell me about this queue, it's different now
    _send(socket1, "c.matchmaking.get_queue_info #{queue.id}\n")
    reply = _recv(socket1)
    assert reply == "s.matchmaking.queue_info #{queue.id}\ttest_queue\t0\t0\n"

    # And rejoin
    _send(socket1, "c.matchmaking.join_queue #{queue.id}\n")
    reply = _recv(socket1)
    assert reply == "OK cmd=c.matchmaking.join_queue\t#{queue.id}\n"

    # Trigger the queue server and see if anything happens
    send(queue.pid, :tick)
    reply = _recv(socket1)
    assert reply == :timeout

    # Now get the second user to join
    _send(socket2, "c.matchmaking.join_queue #{queue.id}\n")
    reply = _recv(socket2)
    assert reply =~ "OK cmd=c.matchmaking.join_queue\t#{queue.id}\n"

    # Check server state
    state = GenServer.call(queue.pid, :get_state)
    assert state.unmatched_players == [user1.id, user2.id]
    assert state.matched_players == []
    assert state.players_accepted == []

    # Tick, we expect to be send a pair of ready checks
    send(queue.pid, :tick)
    reply = _recv(socket1)
    assert reply == "s.matchmaking.ready_check #{queue.id}\n"
    reply = _recv(socket2)
    assert reply == "s.matchmaking.ready_check #{queue.id}\n"

    # Accept the first
    _send(socket1, "c.matchmaking.ready\n")
    reply = _recv(socket1)
    assert reply == :timeout

    # Lets see what the state of the queue_server is
    state = GenServer.call(queue.pid, :get_state)
    assert state.finding_battle == false
    assert state.unmatched_players == []
    assert state.matched_players == [user1.id, user2.id]
    assert state.players_accepted == [user1.id]
    assert state.waiting_for_players == [user2.id]

    # And the second
    _send(socket2, "c.matchmaking.ready\n")
    reply = _recv(socket2)
    assert reply == :timeout

    state = GenServer.call(queue.pid, :get_state)
    assert state.finding_battle == true
    assert state.unmatched_players == []
    assert state.matched_players == [user1.id, user2.id]
    assert state.players_accepted == [user1.id, user2.id]
    assert state.waiting_for_players == []

    # Tick, it shouldn't result in a change since there's no battles open
    send(queue.pid, :tick)
    state2 = GenServer.call(queue.pid, :get_state)
    assert state == state2

    # Now lets create a battle
    _recv(battle_socket)

    _send(
      battle_socket,
      "OPENBATTLE 0 0 empty 322 16 gameHash 0 mapHash engineName\tengineVersion\tmapName\tgameTitle\tgameName\n"
    )

    # We know the battle is being opened, don't need to worry about it
    _recv(socket1)
    _recv(socket2)

    reply = _recv(battle_socket)
    [_all, battle_id] = Regex.run(~r/BATTLEOPENED ([0-9]+) [0-9]/, reply)
    battle_id = int_parse(battle_id)

    # Now we have a battle open, tick should matter
    send(queue.pid, :tick)
    state = GenServer.call(queue.pid, :get_state)
    assert state.finding_battle == false
    assert state.matched_players == []
    assert state.player_count == 0
    assert state.ready_started_at == nil

    # Commands should be sent to user1 and user2
    reply = _recv(socket1)
    assert reply =~ "JOINBATTLE #{battle_id} gameHash\n"
    reply = _recv(socket2)
    assert reply =~ "JOINBATTLE #{battle_id} gameHash\n"
  end
end
