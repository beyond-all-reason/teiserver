defmodule Teiserver.TachyonMatchmakingTest do
  use Central.ServerCase, async: false
  require Logger
  alias Teiserver.{Client, Game}
  alias Teiserver.Battle.Lobby
  alias Teiserver.Data.Matchmaking
  alias Teiserver.Common.PubsubListener
  import Central.Helpers.NumberHelper, only: [int_parse: 1]

  import Teiserver.TeiserverTestLib,
    only: [tachyon_auth_setup: 0, _tachyon_send: 2, _tachyon_recv: 1, _tachyon_recv_until: 1]

  setup do
    Teiserver.Coordinator.start_coordinator()
    %{socket: socket, user: user} = tachyon_auth_setup()
    {:ok, socket: socket, user: user}
  end

  test "queue wait lifecycle", %{socket: socket1, user: user1} do
    {:ok, queue} =
      Game.create_queue(%{
        "name" => "test_queue",
        "team_size" => 1,
        "icon" => "fa-regular fa-home",
        "colour" => "#112233",
        "map_list" => ["map1"],
        "conditions" => %{},
        "settings" => %{
          "tick_interval" => 60_000
        }
      })

    wait_listener = PubsubListener.new_listener(["teiserver_queue_wait:#{queue.id}"])
    match_listener = PubsubListener.new_listener(["teiserver_queue_match:#{queue.id}"])
    queue = Matchmaking.get_queue(queue.id)

    %{socket: socket2, user: user2} = tachyon_auth_setup()
    %{socket: socket3, user: user3} = tachyon_auth_setup()
    %{socket: battle_socket, user: _host_user} = tachyon_auth_setup()

    # Clear both sockets
    _tachyon_recv(socket1)
    _tachyon_recv(socket2)
    _tachyon_recv(socket3)

    # Join the queue
    _tachyon_send(socket1, %{cmd: "c.matchmaking.join_queue", queue_id: queue.id})
    [reply] = _tachyon_recv(socket1)
    assert reply == %{
      "cmd" => "s.matchmaking.join_queue",
      "queue_id" => queue.id,
      "result" => "success"
    }

    pid = Matchmaking.get_queue_wait_pid(queue.id)
    assert :sys.get_state(pid) |> Map.get(:player_list) == [user1.id]

    # Trigger the queue server and see if anything happens
    send(pid, :tick)
    reply = _tachyon_recv(socket1)
    assert reply == :timeout

    # Now get the second user to join
    _tachyon_send(socket2, %{cmd: "c.matchmaking.join_queue", queue_id: queue.id})
    [reply] = _tachyon_recv(socket2)
    assert reply == %{
      "cmd" => "s.matchmaking.join_queue",
      "queue_id" => queue.id,
      "result" => "success"
    }

    assert :sys.get_state(pid) |> Map.get(:player_list) == [user2.id, user1.id]
    assert :sys.get_state(pid) |> Map.get(:player_count) == 2

    # Now increase range so they match
    send(pid, :increase_range)
    send(pid, :tick)

    :timer.sleep(50)

    messages = PubsubListener.get(match_listener)
    assert Enum.count(messages) == 1
    {:queue_wait, :match_attempt, matched_queue_id, match_id} = hd(messages)
    assert matched_queue_id == queue.id

    assert :sys.get_state(pid) |> Map.get(:player_list) == []
    assert :sys.get_state(pid) |> Map.get(:player_count) == 0

    match_server_pid = Matchmaking.get_queue_match_pid(match_id)
    match_state = :sys.get_state(match_server_pid)

    # We don't know for sure the order these will be in so we check like this
    assert Enum.member?(match_state.members, user1.id)
    assert Enum.member?(match_state.members, user2.id)
    assert Enum.count(match_state.members) == 2
  end

  test "joining and leaving all queues", %{socket: socket, user: user} do
    {:ok, queue1} =
      Game.create_queue(%{
        "name" => "test_queue_join_leave1",
        "team_size" => 1,
        "icon" => "fa-regular fa-home",
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
        "icon" => "fa-regular fa-home",
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
    _tachyon_send(socket, %{cmd: "c.matchmaking.query", query: %{}})
    [reply] = _tachyon_recv(socket)
    assert reply["cmd"] == "s.matchmaking.query"
    queue_map = reply["queues"] |> Map.new(fn q -> {q["id"], q} end)

    assert Map.has_key?(queue_map, queue1.id)
    assert Map.has_key?(queue_map, queue2.id)

    # List my queues, should be empty
    _tachyon_send(socket, %{cmd: "c.matchmaking.list_my_queues"})
    [reply] = _tachyon_recv(socket)
    assert reply["cmd"] == "s.matchmaking.your_queue_list"
    assert reply["result"] == "success"
    assert reply["queues"] == []

    # Tell me about this queue
    _tachyon_send(socket, %{cmd: "c.matchmaking.get_queue_info", queue_id: queue1.id})
    [reply] = _tachyon_recv(socket)
    assert reply["cmd"] == "s.matchmaking.queue_info"
    assert reply["queue"] == %{
      "last_wait_time" => 0,
      "name" => "test_queue_join_leave1",
      "player_count" => 0,
      "queue_id" => queue1.id
    }

    # Join a queue that doesn't exist
    _tachyon_send(socket, %{cmd: "c.matchmaking.join_queue", queue_id: 0})
    [reply] = _tachyon_recv(socket)
    assert reply == %{
      "cmd" => "s.matchmaking.join_queue",
      "queue_id" => 0,
      "reason" => "No queue found",
      "result" => "failure"
    }

    # Join the queue (just the first player)
    _tachyon_send(socket, %{cmd: "c.matchmaking.join_queue", queue_id: queue1.id})
    [reply] = _tachyon_recv(socket)
    assert reply == %{
      "cmd" => "s.matchmaking.join_queue",
      "queue_id" => queue1.id,
      "result" => "success"
    }

    # List my queues, should have this one queue
    _tachyon_send(socket, %{cmd: "c.matchmaking.list_my_queues"})
    [reply] = _tachyon_recv(socket)
    assert reply["cmd"] == "s.matchmaking.your_queue_list"
    assert reply["result"] == "success"
    assert Enum.count(reply["queues"]) == 1
    assert hd(reply["queues"])["id"] == queue1.id

    # Get the queue info
    _tachyon_send(socket, %{cmd: "c.matchmaking.get_queue_info", queue_id: queue1.id})
    [reply] = _tachyon_recv(socket)
    assert reply["cmd"] == "s.matchmaking.queue_info"
    assert reply["queue"] == %{
      "last_wait_time" => 0,
      "name" => "test_queue_join_leave1",
      "player_count" => 1,
      "queue_id" => queue1.id
    }

    # Leave the queue
    _tachyon_send(socket, %{cmd: "c.matchmaking.leave_queue", queue_id: queue1.id})
    reply = _tachyon_recv(socket)
    assert reply == :timeout

    # List my queues, should be empty
    _tachyon_send(socket, %{cmd: "c.matchmaking.list_my_queues"})
    [reply] = _tachyon_recv(socket)
    assert reply["cmd"] == "s.matchmaking.your_queue_list"
    assert reply["result"] == "success"
    assert reply["queues"] == []

    user_queues = GenServer.call(client_pid, {:get, :queues})
    assert user_queues == []

    # Tell me about this queue, it's different now
    _tachyon_send(socket, %{cmd: "c.matchmaking.get_queue_info", queue_id: queue1.id})
    [reply] = _tachyon_recv(socket)
    assert reply["cmd"] == "s.matchmaking.queue_info"
    assert reply["queue"] == %{
      "last_wait_time" => 0,
      "name" => "test_queue_join_leave1",
      "player_count" => 0,
      "queue_id" => queue1.id
    }

    # And rejoin
    _tachyon_send(socket, %{cmd: "c.matchmaking.join_queue #{queue1.id}\n"})
    reply = _tachyon_recv(socket)
    assert reply == "OK cmd=c.matchmaking.join_queue\t#{queue1.id}\n"

    user_queues = GenServer.call(client_pid, {:get, :queues})
    assert user_queues == [queue1.id]

    # Join queue 2
    _tachyon_send(socket, "c.matchmaking.join_queue #{queue2.id}\n")
    reply = _tachyon_recv(socket)
    assert reply == "OK cmd=c.matchmaking.join_queue\t#{queue2.id}\n"

    user_queues = GenServer.call(client_pid, {:get, :queues})
    assert user_queues == [queue2.id, queue1.id]

    # Now leave all queues
    _tachyon_send(socket, "c.matchmaking.leave_all_queues\n")
    reply = _tachyon_recv(socket)
    assert reply == :timeout

    user_queues = GenServer.call(client_pid, {:get, :queues})
    assert user_queues == []
  end

  test "decline ready up", %{socket: socket1, user: user1} do
    {:ok, queue} =
      Game.create_queue(%{
        "name" => "test_queue",
        "team_size" => 1,
        "icon" => "fa-regular fa-home",
        "colour" => "#112233",
        "map_list" => ["map1"],
        "conditions" => %{},
        "settings" => %{
          "tick_interval" => 60_000
        }
      })

    queue = Matchmaking.get_queue(queue.id)
    %{socket: socket2, user: user2} = tachyon_auth_setup()

    # Clear both sockets
    _tachyon_recv(socket1)
    _tachyon_recv(socket2)

    # Join the queue
    _tachyon_send(socket1, "c.matchmaking.join_queue #{queue.id}\n")
    reply = _tachyon_recv(socket1)
    assert reply == "OK cmd=c.matchmaking.join_queue\t#{queue.id}\n"

    # Now get the second user to join
    _tachyon_send(socket2, "c.matchmaking.join_queue #{queue.id}\n")
    reply = _tachyon_recv(socket2)
    assert reply =~ "OK cmd=c.matchmaking.join_queue\t#{queue.id}\n"

    # Check server state
    state = GenServer.call(Matchmaking.get_queue_wait_pid(queue.id), :get_state)
    assert state.unmatched_players == [user2.id, user1.id]
    assert state.matched_players == []
    assert state.players_accepted == []

    # Tick, we expect to be send a pair of ready checks
    send(Matchmaking.get_queue_wait_pid(queue.id), :tick)
    reply = _tachyon_recv(socket1)
    assert reply == "s.matchmaking.ready_check #{queue.id}\n"
    reply = _tachyon_recv(socket2)
    assert reply == "s.matchmaking.ready_check #{queue.id}\n"

    # Accept the first
    _tachyon_send(socket1, "c.matchmaking.ready\n")
    reply = _tachyon_recv(socket1)
    assert reply == :timeout

    # Lets see what the state of the queue_server is
    state = GenServer.call(Matchmaking.get_queue_wait_pid(queue.id), :get_state)
    assert state.finding_battle == false
    assert state.unmatched_players == []
    assert state.matched_players == [user1.id, user2.id]
    assert state.players_accepted == [user1.id]
    assert state.waiting_for_players == [user2.id]

    # And the second gets rejected
    _tachyon_send(socket2, "c.matchmaking.decline\n")
    reply = _tachyon_recv(socket2)
    assert reply == :timeout

    state = GenServer.call(Matchmaking.get_queue_wait_pid(queue.id), :get_state)
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
        "icon" => "fa-regular fa-home",
        "colour" => "#112233",
        "map_list" => ["map1"],
        "conditions" => %{},
        "settings" => %{
          "tick_interval" => 60_000,
          "ready_wait_time" => 1
        }
      })

    queue = Matchmaking.get_queue(queue.id)
    %{socket: socket2, user: user2} = tachyon_auth_setup()

    # Clear both sockets
    _tachyon_recv(socket1)
    _tachyon_recv(socket2)

    # Join the queue
    _tachyon_send(socket1, "c.matchmaking.join_queue #{queue.id}\n")
    reply = _tachyon_recv(socket1)
    assert reply == "OK cmd=c.matchmaking.join_queue\t#{queue.id}\n"

    # Now get the second user to join
    _tachyon_send(socket2, "c.matchmaking.join_queue #{queue.id}\n")
    reply = _tachyon_recv(socket2)
    assert reply =~ "OK cmd=c.matchmaking.join_queue\t#{queue.id}\n"

    # Check server state
    state = GenServer.call(Matchmaking.get_queue_wait_pid(queue.id), :get_state)
    assert state.unmatched_players == [user2.id, user1.id]
    assert state.matched_players == []
    assert state.players_accepted == []

    # Tick, we expect to be send a pair of ready checks
    send(Matchmaking.get_queue_wait_pid(queue.id), :tick)
    reply = _tachyon_recv(socket1)
    assert reply == "s.matchmaking.ready_check #{queue.id}\n"
    reply = _tachyon_recv(socket2)
    assert reply == "s.matchmaking.ready_check #{queue.id}\n"

    # Lets see what the state of the queue_server is
    state = GenServer.call(Matchmaking.get_queue_wait_pid(queue.id), :get_state)
    assert state.finding_battle == false
    assert state.unmatched_players == []
    assert state.matched_players == [user1.id, user2.id]
    assert state.players_accepted == []
    assert state.waiting_for_players == [user1.id, user2.id]

    # Wait for 1 second, tick
    # Previously this caused a bug because we never looked at what happened if "time elapsed"
    # was equal to the ready_wait_time
    :timer.sleep(1000)
    send(Matchmaking.get_queue_wait_pid(queue.id), :tick)
    state = GenServer.call(Matchmaking.get_queue_wait_pid(queue.id), :get_state)
    assert state.finding_battle == false
    assert state.unmatched_players == []
    assert state.matched_players == [user1.id, user2.id]
    assert state.players_accepted == []
    assert state.waiting_for_players == [user1.id, user2.id]

    # Now tick again, should take us over
    :timer.sleep(1000)
    send(Matchmaking.get_queue_wait_pid(queue.id), :tick)
    state = GenServer.call(Matchmaking.get_queue_wait_pid(queue.id), :get_state)
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
        "icon" => "fa-regular fa-home",
        "colour" => "#112233",
        "map_list" => ["map1"],
        "conditions" => %{},
        "settings" => %{
          "tick_interval" => 60_000,
          "ready_wait_time" => 1
        }
      })

    queue = Matchmaking.get_queue(queue.id)
    %{socket: socket2, user: user2} = tachyon_auth_setup()

    # Clear both sockets
    _tachyon_recv(socket1)
    _tachyon_recv(socket2)

    # Join the queue
    _tachyon_send(socket1, "c.matchmaking.join_queue #{queue.id}\n")
    reply = _tachyon_recv(socket1)
    assert reply == "OK cmd=c.matchmaking.join_queue\t#{queue.id}\n"

    # Now get the second user to join
    _tachyon_send(socket2, "c.matchmaking.join_queue #{queue.id}\n")
    reply = _tachyon_recv(socket2)
    assert reply =~ "OK cmd=c.matchmaking.join_queue\t#{queue.id}\n"

    # Check server state
    state = GenServer.call(Matchmaking.get_queue_wait_pid(queue.id), :get_state)
    assert state.unmatched_players == [user2.id, user1.id]
    assert state.matched_players == []
    assert state.players_accepted == []

    # Tick, we expect to be send a pair of ready checks
    send(Matchmaking.get_queue_wait_pid(queue.id), :tick)
    reply = _tachyon_recv(socket1)
    assert reply == "s.matchmaking.ready_check #{queue.id}\n"
    reply = _tachyon_recv(socket2)
    assert reply == "s.matchmaking.ready_check #{queue.id}\n"

    # Lets see what the state of the queue_server is
    state = GenServer.call(Matchmaking.get_queue_wait_pid(queue.id), :get_state)
    assert state.finding_battle == false
    assert state.unmatched_players == []
    assert state.matched_players == [user1.id, user2.id]
    assert state.players_accepted == []
    assert state.waiting_for_players == [user1.id, user2.id]

    # Accept the first
    _tachyon_send(socket1, "c.matchmaking.ready\n")
    reply = _tachyon_recv(socket1)
    assert reply == :timeout

    # Tick us over the limit, the first player should be still in the queue
    # but the 2nd player should be gone
    :timer.sleep(2000)
    send(Matchmaking.get_queue_wait_pid(queue.id), :tick)
    state = GenServer.call(Matchmaking.get_queue_wait_pid(queue.id), :get_state)
    assert state.finding_battle == false
    assert state.unmatched_players == [user1.id]
    assert state.matched_players == []
    assert state.players_accepted == []
    assert state.waiting_for_players == []
  end
end
