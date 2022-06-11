defmodule Teiserver.TachyonMatchmakingTest do
  use Central.ServerCase, async: false
  require Logger
  alias Teiserver.{Client, Game, User}
  alias Teiserver.Account.ClientLib
  alias Teiserver.Data.Matchmaking
  alias Teiserver.Common.PubsubListener

  import Teiserver.TeiserverTestLib,
    only: [tachyon_auth_setup: 0, _tachyon_send: 2, _tachyon_recv: 1, _tachyon_recv_until: 1]

  setup do
    Teiserver.Coordinator.start_coordinator()
    %{socket: socket, user: user} = tachyon_auth_setup()
    {:ok, socket: socket, user: user}
  end

  defp make_empty_lobby() do
    %{socket: hsocket, user: host} = tachyon_auth_setup()

    # User needs to be a moderator (at this time) to start/stop Coordinator mode
    User.update_user(%{host | moderator: true})
    ClientLib.refresh_client(host.id)

    lobby_data = %{
      cmd: "c.lobby.create",
      name: "EU Matchmaking #{:rand.uniform(999_999_999)}",
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

    %{
      lobby_id: lobby_id,
      hsocket: hsocket,
      host: host
    }
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

    match_listener = PubsubListener.new_listener(["teiserver_queue_match:#{queue.id}"])
    queue = Matchmaking.get_queue(queue.id)

    %{socket: socket2, user: user2} = tachyon_auth_setup()
    %{socket: socket3, user: _user3} = tachyon_auth_setup()

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
    assert :sys.get_state(pid) |> Map.get(:wait_list) == [{user1.id, :user}]

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

    # This part of the test fails because it is set to instantly match people
    # assert :sys.get_state(pid) |> Map.get(:wait_list) == [{user2.id, :user}, {user1.id, :user}]
    # assert :sys.get_state(pid) |> Map.get(:member_count) == 2

    # # Now increase range so they match
    # send(pid, :increase_range)
    # send(pid, :tick)

    # :timer.sleep(50)

    messages = PubsubListener.get(match_listener)
    # assert Enum.count(messages) == 1
    {:queue_wait, :match_attempt, matched_queue_id, match_id} = hd(messages)
    assert matched_queue_id == queue.id

    assert :sys.get_state(pid) |> Map.get(:wait_list) == []

    match_server_pid = Matchmaking.get_queue_match_pid(match_id)
    match_state = :sys.get_state(match_server_pid)

    # Teams includes time based data, thus we can't directly test it
    stripped_teams = match_state.teams
      |> Enum.map(fn {id, _time, _range, type} -> {id, type} end)

    # We don't know for sure the order these will be in so we check like this
    assert Enum.member?(stripped_teams, {user1.id, :user})
    assert Enum.member?(stripped_teams, {user2.id, :user})
    assert Enum.count(match_state.teams) == 2

    assert Enum.member?(match_state.users, user1.id)
    assert Enum.member?(match_state.users, user2.id)
    assert Enum.count(match_state.users) == 2
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
      "mean_wait_time" => 0,
      "name" => "test_queue_join_leave1",
      "member_count" => 0,
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
      "mean_wait_time" => 0,
      "name" => "test_queue_join_leave1",
      "member_count" => 1,
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

    user_queues = :sys.get_state(client_pid) |> Map.get(:queues)
    assert user_queues == []

    # Tell me about this queue, it's different now
    _tachyon_send(socket, %{cmd: "c.matchmaking.get_queue_info", queue_id: queue1.id})
    [reply] = _tachyon_recv(socket)
    assert reply["cmd"] == "s.matchmaking.queue_info"
    assert reply["queue"] == %{
      "mean_wait_time" => 0,
      "name" => "test_queue_join_leave1",
      "member_count" => 0,
      "queue_id" => queue1.id
    }

    # And rejoin
    _tachyon_send(socket, %{cmd: "c.matchmaking.join_queue", queue_id: queue1.id})
    [reply] = _tachyon_recv(socket)
    assert reply == %{
      "cmd" => "s.matchmaking.join_queue",
      "queue_id" => queue1.id,
      "result" => "success"
    }

    user_queues = :sys.get_state(client_pid) |> Map.get(:queues)
    assert user_queues == [queue1.id]

    # Join again, see what happens
    _tachyon_send(socket, %{cmd: "c.matchmaking.join_queue", queue_id: queue1.id})
    [reply] = _tachyon_recv(socket)
    assert reply == %{
      "cmd" => "s.matchmaking.join_queue",
      "queue_id" => queue1.id,
      "result" => "success"
    }

    # It should still just have 1 of us in it
    user_queues = :sys.get_state(client_pid) |> Map.get(:queues)
    assert user_queues == [queue1.id]

    # Join queue 2
    _tachyon_send(socket, %{cmd: "c.matchmaking.join_queue", queue_id: queue2.id})
    [reply] = _tachyon_recv(socket)
    assert reply == %{
      "cmd" => "s.matchmaking.join_queue",
      "queue_id" => queue2.id,
      "result" => "success"
    }

    user_queues = :sys.get_state(client_pid) |> Map.get(:queues)
    assert user_queues == [queue2.id, queue1.id]

    # Now leave all queues
    _tachyon_send(socket, %{cmd: "c.matchmaking.leave_all_queues"})
    reply = _tachyon_recv(socket)
    assert reply == :timeout

    user_queues = :sys.get_state(client_pid) |> Map.get(:queues)
    assert user_queues == []
  end

  test "one accept and one decline", %{socket: socket1, user: user1} do
    {:ok, queue} =
      Game.create_queue(%{
        "name" => "test_queue",
        "team_size" => 1,
        "icon" => "fa-regular fa-home",
        "colour" => "#112233",
        "map_list" => ["map1"],
        "conditions" => %{},
        "settings" => %{
          "ready_wait_time" => 60_000,
          "ready_tick_interval" => 60_000,
        }
      })

    queue = Matchmaking.get_queue(queue.id)
    %{socket: socket2, user: user2} = tachyon_auth_setup()

    # Clear both sockets
    _tachyon_recv(socket1)
    _tachyon_recv(socket2)

    # Create the match process
    {match_pid, match_id, teams} = Matchmaking.create_match([{user2.id, 1000, 1, :user}, {user1.id, 1000, 1, :user}], queue.id)
    assert teams == [{user2.id, 1000, 1, :user}, {user1.id, 1000, 1, :user}]

    wait_pid = Matchmaking.get_queue_wait_pid(queue.id)

    # Check server state
    state = :sys.get_state(match_pid)
    assert state.users == [user2.id, user1.id]
    assert state.pending_accepts == [user2.id, user1.id]
    assert state.accepted_users == []
    assert state.declined_users == []

    # Tick, we expect to be send a pair of ready checks
    send(match_pid, :tick)
    [reply] = _tachyon_recv(socket1)
    assert reply == %{
      "cmd" => "s.matchmaking.match_ready",
      "match_id" => match_id,
      "queue_id" => queue.id
    }
    [reply] = _tachyon_recv(socket2)
    assert reply == %{
      "cmd" => "s.matchmaking.match_ready",
      "match_id" => match_id,
      "queue_id" => queue.id
    }

    # Accept the first
    _tachyon_send(socket1, %{cmd: "c.matchmaking.accept", match_id: match_id})
    reply = _tachyon_recv(socket1)
    assert reply == :timeout

    state = :sys.get_state(match_pid)
    assert state.users == [user2.id, user1.id]
    assert state.pending_accepts == [user2.id]
    assert state.accepted_users == [user1.id]
    assert state.declined_users == []

    # And the second declines
    _tachyon_send(socket2, %{cmd: "c.matchmaking.decline", match_id: match_id})
    reply = _tachyon_recv(socket2)
    assert reply == :timeout

    state = :sys.get_state(match_pid)
    assert state.users == [user2.id, user1.id]
    assert state.pending_accepts == []
    assert state.accepted_users == [user1.id]
    assert state.declined_users == [user2.id]

    # Now send it a tick
    send(match_pid, :tick)
    :timer.sleep(500)
    refute Process.alive?(match_pid)
    assert Matchmaking.get_queue_match_pid(match_id) == nil

    # Check wait state
    wait_state = :sys.get_state(wait_pid)
    assert wait_state.wait_list == [{user1.id, :user}]
    refute wait_state.buckets == %{}
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
          "ready_wait_time" => 60_000
        }
      })

    queue = Matchmaking.get_queue(queue.id)
    %{socket: socket2, user: user2} = tachyon_auth_setup()

    wait_pid = Matchmaking.get_queue_wait_pid(queue.id)

    # Clear both sockets
    _tachyon_recv(socket1)
    _tachyon_recv(socket2)

    # Create the match process
    {match_pid, match_id, teams} = Matchmaking.create_match([{user2.id, 1000, 1, :user}, {user1.id, 1000, 1, :user}], queue.id)
    assert teams == [{user2.id, 1000, 1, :user}, {user1.id, 1000, 1, :user}]

    # Check server states
    match_state = :sys.get_state(match_pid)
    assert match_state.users == [user2.id, user1.id]
    assert match_state.pending_accepts == [user2.id, user1.id]
    assert match_state.accepted_users == []
    assert match_state.declined_users == []

    wait_state = :sys.get_state(wait_pid)
    assert wait_state.wait_list == []
    assert wait_state.buckets == %{}

    send(match_pid, :end_waiting)
    :timer.sleep(500)
    refute Process.alive?(match_pid)
    assert Matchmaking.get_queue_match_pid(match_id) == nil

    # Check wait state
    wait_state = :sys.get_state(wait_pid)
    assert wait_state.wait_list == []
    assert wait_state.buckets == %{}
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
          "ready_wait_time" => 60_000
        }
      })

    queue = Matchmaking.get_queue(queue.id)
    %{socket: socket2, user: user2} = tachyon_auth_setup()

    wait_pid = Matchmaking.get_queue_wait_pid(queue.id)

    # Create the match process
    {match_pid, match_id, teams} = Matchmaking.create_match([{user2.id, 1000, 1, :user}, {user1.id, 1000, 1, :user}], queue.id)
    assert teams == [{user2.id, 1000, 1, :user}, {user1.id, 1000, 1, :user}]

    # Clear both sockets
    _tachyon_recv(socket1)
    _tachyon_recv(socket2)

    # Check server states
    match_state = :sys.get_state(match_pid)
    assert match_state.users == [user2.id, user1.id]
    assert match_state.pending_accepts == [user2.id, user1.id]
    assert match_state.accepted_users == []
    assert match_state.declined_users == []

    wait_state = :sys.get_state(wait_pid)
    assert wait_state.wait_list == []
    assert wait_state.buckets == %{}

    # Accept user user1
    _tachyon_send(socket1, %{cmd: "c.matchmaking.accept", match_id: match_id})
    reply = _tachyon_recv(socket1)
    assert reply == :timeout

    state = :sys.get_state(match_pid)
    assert state.users == [user2.id, user1.id]
    assert state.pending_accepts == [user2.id]
    assert state.accepted_users == [user1.id]
    assert state.declined_users == []

    send(match_pid, :end_waiting)
    :timer.sleep(500)
    refute Process.alive?(match_pid)
    assert Matchmaking.get_queue_match_pid(match_id) == nil

    # Users hear what?
    [reply] = _tachyon_recv(socket1)
    assert reply == %{
      "cmd" => "s.matchmaking.match_cancelled",
      "match_id" => match_id,
      "queue_id" => queue.id
    }

    [reply] = _tachyon_recv(socket2)
    assert reply == %{
      "cmd" => "s.matchmaking.match_declined",
      "match_id" => match_id,
      "queue_id" => queue.id
    }

    # Check wait state
    wait_state = :sys.get_state(wait_pid)
    assert wait_state.wait_list == [{user1.id, :user}]
    refute wait_state.buckets == %{}
  end

  test "they both accept", %{socket: socket1, user: user1} do
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
          "ready_wait_time" => 60_000
        }
      })

    queue = Matchmaking.get_queue(queue.id)
    %{socket: socket2, user: user2} = tachyon_auth_setup()

    wait_pid = Matchmaking.get_queue_wait_pid(queue.id)

    # Create the match process
    {match_pid, match_id, teams} = Matchmaking.create_match([{user2.id, 1000, 1, :user}, {user1.id, 1000, 1, :user}], queue.id)
    assert teams == [{user2.id, 1000, 1, :user}, {user1.id, 1000, 1, :user}]

    # Clear both sockets
    _tachyon_recv_until(socket1)
    _tachyon_recv_until(socket2)

    # Check server states
    match_state = :sys.get_state(match_pid)
    assert match_state.users == [user2.id, user1.id]
    assert match_state.pending_accepts == [user2.id, user1.id]
    assert match_state.accepted_users == []
    assert match_state.declined_users == []

    wait_state = :sys.get_state(wait_pid)
    assert wait_state.wait_list == []
    assert wait_state.buckets == %{}

    # Ensure we have an open and empty battle
    %{
      # lobby_id: lobby_id
    } = make_empty_lobby()

    # Accept user user1
    _tachyon_send(socket1, %{cmd: "c.matchmaking.accept", match_id: match_id})
    _tachyon_send(socket2, %{cmd: "c.matchmaking.accept", match_id: match_id})
    :timer.sleep(100)

    [reply] = _tachyon_recv(socket1)
    assert reply["cmd"] == "s.lobby.force_join"

    [reply] = _tachyon_recv(socket2)
    assert reply["cmd"] == "s.lobby.force_join"

    # Clear both sockets
    _tachyon_recv_until(socket1)
    _tachyon_recv_until(socket2)

    # Wait for it to do everything
    :timer.sleep(1000)

    state = :sys.get_state(match_pid)
    assert state.users == [user2.id, user1.id]
    assert state.pending_accepts == []
    assert state.accepted_users == [user2.id, user1.id]
    assert state.declined_users == []

    send(match_pid, :end_waiting)
    :timer.sleep(500)
    refute Process.alive?(match_pid)
    assert Matchmaking.get_queue_match_pid(match_id) == nil

    # Check wait state
    wait_state = :sys.get_state(wait_pid)
    assert wait_state.wait_list == []
    refute wait_state.buckets == %{}
  end
end
