defmodule Teiserver.SpringMatchmakingTest do
  use Central.ServerCase, async: false
  require Logger
  alias Teiserver.Game
  alias Teiserver.Data.Matchmaking

  import Teiserver.TestLib,
    only: [auth_setup: 0, _send: 2, _recv: 1, _recv_until: 1, new_user: 0, new_user: 2]

  setup do
    %{socket: socket, user: user} = auth_setup()
    {:ok, socket: socket, user: user}
  end

  test "Test queuing", %{socket: socket1, user: user1} do
    {:ok, queue} = Game.create_queue(%{
      "name" => "test_queue",
      "team_size" => 1,
      "icon" => "far fa-home",
      "colour" => "#112233",
      "map_list" => ["map1"],
      "conditions" => %{},
      "settings" => %{},
    })
    queue = Matchmaking.get_queue(queue.id)

    %{socket: socket2, user: user2} = auth_setup()

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

    # Join a queue that doesn't exist
    _send(socket1, "c.matchmaking.join_queue 0\n")
    reply = _recv(socket1)
    assert reply == "NO cmd=c.matchmaking.join_queue\t0\n"

    # Join the queue (just the first player)
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
    assert reply == "OK cmd=c.matchmaking.join_queue\t#{queue.id}\n"

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
    assert state.unmatched_players == []
    assert state.matched_players == [user1.id, user2.id]
    assert state.players_accepted == [user1.id]
    assert state.waiting_for_players == [user2.id]

    # And the second
    _send(socket2, "c.matchmaking.ready\n")
    reply = _recv(socket2)
    assert reply == :timeout

    state = GenServer.call(queue.pid, :get_state)
    IO.puts ""
    IO.inspect state
    IO.puts ""

    _send(socket1, "EXIT\n")
    _recv(socket1)

    _send(socket2, "EXIT\n")
    _recv(socket2)
  end
end
