defmodule Teiserver.TachyonMatchmakingTest do
  use Central.ServerCase, async: false
  require Logger
  alias Teiserver.{Client, Battle, Game, User, Account}
  alias Teiserver.Account.ClientLib
  alias Teiserver.Data.Matchmaking
  alias Teiserver.Game.MatchRatingLib
  alias Teiserver.Common.PubsubListener

  import Teiserver.TeiserverTestLib,
    only: [tachyon_auth_setup: 0, _tachyon_send: 2, _tachyon_recv: 1, _tachyon_recv_until: 1]

  setup do
    Teiserver.Coordinator.start_coordinator()
    %{socket: socket, user: user} = tachyon_auth_setup()
    {:ok, socket: socket, user: user}
  end

  defp make_rating(userid, rating_type_id, rating_value) do
    {:ok, _} = Account.create_rating(%{
      user_id: userid,
      rating_type_id: rating_type_id,
      rating_value: rating_value,
      skill: rating_value,
      uncertainty: 0,
      leaderboard_rating: rating_value,
      last_updated: Timex.now(),
    })
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
        "name" => "test_queue-1v1",
        "team_size" => 1,
        "team_count" => 2,
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
    groups = :sys.get_state(pid) |> Map.get(:groups_map)
    assert Map.has_key?(groups, user1.id)
    assert groups[user1.id].members == [user1.id]

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

    # Tick the wait server
    send(pid, :tick)
    :timer.sleep(300)

    messages = PubsubListener.get(match_listener)
    {:queue_wait, :match_attempt, matched_queue_id, match_id} = hd(messages)
    assert matched_queue_id == queue.id

    groups = :sys.get_state(pid) |> Map.get(:groups_map)
    assert groups == %{}

    match_server_pid = Matchmaking.get_queue_match_pid(match_id)
    match_state = :sys.get_state(match_server_pid)

    # We don't know for sure the order these will be in so we check like this
    assert match_state.teams[1] == [user2.id]
    assert match_state.teams[2] == [user1.id]
    assert Enum.count(match_state.teams) == 2

    assert Enum.member?(match_state.user_ids, user1.id)
    assert Enum.member?(match_state.user_ids, user2.id)
    assert Enum.count(match_state.user_ids) == 2
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
    client_pid = Client.get_client_by_id(user.id).tcp_pid

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
    # should be nothing as we're already in the queue
    _tachyon_send(socket, %{cmd: "c.matchmaking.join_queue", queue_id: queue1.id})
    reply = _tachyon_recv(socket)
    assert reply == :timeout

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

    # Extra group data
    extra_group_data = %{bucket: 17, search_distance: 3}

    # Create the match process
    {match_pid, match_id} = Matchmaking.create_match([
      Matchmaking.make_group_from_userid(user2.id, queue) |> Map.merge(extra_group_data),
      Matchmaking.make_group_from_userid(user1.id, queue) |> Map.merge(extra_group_data)
    ], queue.id)

    wait_pid = Matchmaking.get_queue_wait_pid(queue.id)

    # Check server state
    state = :sys.get_state(match_pid)
    assert state.user_ids == [user2.id, user1.id]
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
    assert state.user_ids == [user2.id, user1.id]
    assert state.pending_accepts == [user2.id]
    assert state.accepted_users == [user1.id]
    assert state.declined_users == []

    # And the second declines
    _tachyon_send(socket2, %{cmd: "c.matchmaking.decline", match_id: match_id})
    reply = _tachyon_recv(socket2)
    assert reply == :timeout

    state = :sys.get_state(match_pid)
    assert state.user_ids == [user2.id, user1.id]
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
    assert wait_state.groups_map |> Map.has_key?(user1.id)

    # Now ensure it added the group into 7 buckets (17 +/- 3)
    assert wait_state.buckets == %{
      14 => [user1.id],
      15 => [user1.id],
      16 => [user1.id],
      17 => [user1.id],
      18 => [user1.id],
      19 => [user1.id],
      20 => [user1.id]
    }
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

    # Extra group data
    extra_group_data = %{bucket: 17, search_distance: 1}

    # Create the match process
    {match_pid, match_id} = Matchmaking.create_match([
      Matchmaking.make_group_from_userid(user2.id, queue) |> Map.merge(extra_group_data),
      Matchmaking.make_group_from_userid(user1.id, queue) |> Map.merge(extra_group_data)
    ], queue.id)

    # Check server states
    match_state = :sys.get_state(match_pid)
    assert match_state.user_ids == [user2.id, user1.id]
    assert match_state.pending_accepts == [user2.id, user1.id]
    assert match_state.accepted_users == []
    assert match_state.declined_users == []

    wait_state = :sys.get_state(wait_pid)
    assert wait_state.groups_map == %{}
    assert wait_state.buckets == %{}

    send(match_pid, :end_waiting)
    :timer.sleep(500)
    refute Process.alive?(match_pid)
    assert Matchmaking.get_queue_match_pid(match_id) == nil

    # Check wait state
    wait_state = :sys.get_state(wait_pid)
    assert wait_state.groups_map == %{}
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

    # Extra group data
    extra_group_data = %{bucket: 17, search_distance: 1}

    # Create the match process
    {match_pid, match_id} = Matchmaking.create_match([
      Matchmaking.make_group_from_userid(user2.id, queue) |> Map.merge(extra_group_data),
      Matchmaking.make_group_from_userid(user1.id, queue) |> Map.merge(extra_group_data)
    ], queue.id)

    # Clear both sockets
    _tachyon_recv(socket1)
    _tachyon_recv(socket2)

    # Check server states
    match_state = :sys.get_state(match_pid)
    assert match_state.user_ids == [user2.id, user1.id]
    assert match_state.pending_accepts == [user2.id, user1.id]
    assert match_state.accepted_users == []
    assert match_state.declined_users == []

    wait_state = :sys.get_state(wait_pid)
    assert wait_state.groups_map == %{}
    assert wait_state.buckets == %{}

    # Accept user user1
    _tachyon_send(socket1, %{cmd: "c.matchmaking.accept", match_id: match_id})
    reply = _tachyon_recv(socket1)
    assert reply == :timeout

    state = :sys.get_state(match_pid)
    assert state.user_ids == [user2.id, user1.id]
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
    assert wait_state.groups_map |> Map.has_key?(user1.id)

    # Now ensure it added the group into 7 buckets (17 +/- 3)
    assert wait_state.buckets == %{
      16 => [user1.id],
      17 => [user1.id],
      18 => [user1.id]
    }
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

    # Extra group data
    extra_group_data = %{bucket: 17, search_distance: 1}

    # Create the match process
    {match_pid, match_id} = Matchmaking.create_match([
      Matchmaking.make_group_from_userid(user2.id, queue) |> Map.merge(extra_group_data),
      Matchmaking.make_group_from_userid(user1.id, queue) |> Map.merge(extra_group_data)
    ], queue.id)

    # Clear both sockets
    _tachyon_recv_until(socket1)
    _tachyon_recv_until(socket2)

    # Check server states
    match_state = :sys.get_state(match_pid)
    assert match_state.user_ids == [user2.id, user1.id]
    assert match_state.pending_accepts == [user2.id, user1.id]
    assert match_state.accepted_users == []
    assert match_state.declined_users == []

    wait_state = :sys.get_state(wait_pid)
    assert wait_state.groups_map == %{}
    assert wait_state.buckets == %{}

    # Ensure we have an open and empty battle
    %{
      # lobby_id: lobby_id
    } = make_empty_lobby()

    # Accept user user1
    _tachyon_send(socket1, %{cmd: "c.matchmaking.accept", match_id: match_id})
    _tachyon_send(socket2, %{cmd: "c.matchmaking.accept", match_id: match_id})
    :timer.sleep(100)

    [user1.id, user2.id]
      |> Enum.each(fn userid ->
        Account.merge_update_client(userid, %{sync: %{engine: 1, game: 1, map: 1}})
      end)

    [reply] = _tachyon_recv(socket1)
    assert reply["cmd"] == "s.lobby.joined"

    [reply] = _tachyon_recv(socket2)
    assert reply["cmd"] == "s.lobby.joined"

    # Clear both sockets
    _tachyon_recv_until(socket1)
    _tachyon_recv_until(socket2)

    # Wait for it to do everything
    :timer.sleep(1000)

    state = :sys.get_state(match_pid)
    assert state.user_ids == [user2.id, user1.id]
    assert state.pending_accepts == []
    assert state.accepted_users == [user2.id, user1.id]
    assert state.declined_users == []

    send(match_pid, :tick)

    # Check wait state
    wait_state = :sys.get_state(wait_pid)
    assert wait_state.groups_map == %{}
    assert wait_state.buckets == %{}

    # If we tick is that still the case?
    send(wait_pid, :tick)
    wait_state = :sys.get_state(wait_pid)
    assert wait_state.groups_map == %{}
    assert wait_state.buckets == %{}

    # Now tell the match server to cancel the match
    send(match_pid, :end_waiting)
    :timer.sleep(500)
    refute Process.alive?(match_pid)
    assert Matchmaking.get_queue_match_pid(match_id) == nil
  end

  test "Range increases", %{socket: socket1, user: user1} do
    {:ok, queue} =
      Game.create_queue(%{
        "name" => "test_queue-1v1",
        "team_size" => 1,
        "team_count" => 2,
        "icon" => "fa-regular fa-home",
        "colour" => "#112233",
        "map_list" => ["map1"],
        "conditions" => %{},
        "settings" => %{
          "tick_interval" => 60_000
        }
      })

    # Join the queue
    _tachyon_send(socket1, %{cmd: "c.matchmaking.join_queue", queue_id: queue.id})

    pid = Matchmaking.get_queue_wait_pid(queue.id)
    state = :sys.get_state(pid)
    assert Map.has_key?(state.groups_map, user1.id)
    assert state.groups_map[user1.id].members == [user1.id]
    assert state.buckets == %{17 => [user1.id]}

    # Increase range
    send(pid, :increase_range)

    state = :sys.get_state(pid)
    assert Map.has_key?(state.groups_map, user1.id)
    assert state.groups_map[user1.id].members == [user1.id]
    assert state.buckets == %{16 => [user1.id], 17 => [user1.id], 18 => [user1.id]}

    # Increase range a number of times, 1 more time than the max-distance
    0..(state.groups_map[user1.id].max_distance + 1)
      |> Enum.each(fn _ ->
        send(pid, :increase_range)
      end)

    state = :sys.get_state(pid)
    assert Map.has_key?(state.groups_map, user1.id)
    assert state.groups_map[user1.id].members == [user1.id]
    # Easiest way to check if the right number of buckets are being filled
    assert state.buckets |> Map.keys |> Enum.count == (state.groups_map[user1.id].max_distance * 2) + 1
  end

  test "Team queue with both party and solo members", %{socket: socket1, user: user1} do
    {:ok, queue} =
      Game.create_queue(%{
        "name" => "test_queue-3v3",
        "team_size" => 3,
        "team_count" => 2,
        "icon" => "fa-regular fa-home",
        "colour" => "#112233",
        "map_list" => ["map1"],
        "conditions" => %{},
        "settings" => %{
          "tick_interval" => 60_000
        }
      })

    %{socket: socket2, user: user2} = tachyon_auth_setup()
    %{socket: socket3, user: user3} = tachyon_auth_setup()

    %{socket: psocket1, user: puser1} = tachyon_auth_setup()
    %{socket: psocket2, user: puser2} = tachyon_auth_setup()
    %{socket: psocket3, user: puser3} = tachyon_auth_setup()

    # Setup ratings
    rating_type_id = MatchRatingLib.rating_type_name_lookup()["Team"]
    # The solo players should be significantly higher rated than the party
    make_rating(user1.id, rating_type_id, 25)
    make_rating(user2.id, rating_type_id, 25)
    make_rating(user3.id, rating_type_id, 25)

    # The party should be rated based on the highest rated player
    make_rating(puser1.id, rating_type_id, 20.2)
    make_rating(puser2.id, rating_type_id, 5)
    make_rating(puser3.id, rating_type_id, 5)

    # Setup the party
    _tachyon_send(psocket1, %{"cmd" => "c.party.create"})
    [resp] = _tachyon_recv(psocket1)
    assert resp["cmd"] == "s.party.added_to"
    party_id = resp["party"]["id"]

    _tachyon_send(psocket1, %{"cmd" => "c.party.invite", "userid" => puser2.id})
    _tachyon_send(psocket1, %{"cmd" => "c.party.invite", "userid" => puser3.id})

    _tachyon_send(psocket2, %{"cmd" => "c.party.accept", "party_id" => party_id})
    _tachyon_send(psocket3, %{"cmd" => "c.party.accept", "party_id" => party_id})

    # Ensure the party is setup the correct way
    party = Account.get_party(party_id)
    assert party.members == [puser3.id, puser2.id, puser1.id]

    # Clear sockets
    _tachyon_recv_until(psocket1)
    _tachyon_recv_until(psocket2)

    # Now try to join the queue as one of the members
    _tachyon_send(psocket2, %{cmd: "c.matchmaking.join_queue", queue_id: queue.id})
    [reply] = _tachyon_recv(psocket2)
    assert reply == %{
      "cmd" => "s.matchmaking.join_queue",
      "reason" => "Not party leader",
      "result" => "failure",
      "queue_id" => queue.id
    }

    pid = Matchmaking.get_queue_wait_pid(queue.id)
    state = :sys.get_state(pid)
    assert state.groups_map |> Map.keys == []
    assert state.groups_map |> Map.keys == []

    # Now do it properly
    _tachyon_send(psocket1, %{cmd: "c.matchmaking.join_queue", queue_id: queue.id})
    [reply] = _tachyon_recv(psocket1)
    assert reply == %{
      "cmd" => "s.matchmaking.join_queue",
      "result" => "success",
      "queue_id" => queue.id
    }

    state = :sys.get_state(pid)
    assert state.groups_map |> Map.keys == [party.id]
    assert state.buckets == %{20 => [party.id]}
    assert state.groups_map[party.id].rating == 20.2
    assert state.groups_map[party.id].bucket == 20

    # Clear sockets
    _tachyon_recv_until(socket1)
    _tachyon_recv_until(socket2)
    _tachyon_recv_until(socket3)

    # Now get the others to join
    _tachyon_send(socket1, %{cmd: "c.matchmaking.join_queue", queue_id: queue.id})
    _tachyon_send(socket2, %{cmd: "c.matchmaking.join_queue", queue_id: queue.id})
    _tachyon_send(socket3, %{cmd: "c.matchmaking.join_queue", queue_id: queue.id})

    [reply] = _tachyon_recv(socket1)
    assert reply == %{
      "cmd" => "s.matchmaking.join_queue",
      "result" => "success",
      "queue_id" => queue.id
    }

    [reply] = _tachyon_recv(socket2)
    assert reply == %{
      "cmd" => "s.matchmaking.join_queue",
      "result" => "success",
      "queue_id" => queue.id
    }

    [reply] = _tachyon_recv(socket3)
    assert reply == %{
      "cmd" => "s.matchmaking.join_queue",
      "result" => "success",
      "queue_id" => queue.id
    }

    state = :sys.get_state(pid)
    assert state.groups_map |> Map.keys == [user1.id, user2.id, user3.id, party.id]
    assert state.buckets == %{
      25 => [user3.id, user2.id, user1.id],
      20 => [party.id]
    }

    # Clear socket1
    _tachyon_recv_until(socket1)

    send(pid, :tick)

    # Nothing should have happened
    state = :sys.get_state(pid)
    assert state.groups_map |> Map.keys == [user1.id, user2.id, user3.id, party.id]
    assert state.buckets == %{
      25 => [user3.id, user2.id, user1.id],
      20 => [party.id]
    }

    # Okay, now increase the range 5 times
    send(pid, :increase_range)
    send(pid, :increase_range)
    send(pid, :increase_range)
    send(pid, :increase_range)
    send(pid, :increase_range)

    # And tick
    send(pid, :tick)

    state = :sys.get_state(pid)
    assert state.groups_map == %{}
    assert state.buckets == %{}

    [reply] = _tachyon_recv(socket1)
    match_id = reply["match_id"]
    assert reply == %{
      "cmd" => "s.matchmaking.match_ready",
      "match_id" => match_id,
      "queue_id" => queue.id
    }

    pid = Matchmaking.get_queue_match_pid(match_id)
    state = :sys.get_state(pid)
    team1 = state.balance.team_players[1] |> Enum.sort
    team2 = state.balance.team_players[2] |> Enum.sort

    assert team1 == [user1.id, user2.id, user3.id]
    assert team2 == [puser1.id, puser2.id, puser3.id]

    assert state.user_ids |> Enum.sort() == [user1.id, user2.id, user3.id, puser1.id, puser2.id, puser3.id]
    assert state.pending_accepts |> Enum.sort() == [user1.id, user2.id, user3.id, puser1.id, puser2.id, puser3.id]
    assert state.accepted_users == []
    assert state.declined_users == []

    # Add an empty lobby
    %{
      lobby_id: lobby_id
    } = make_empty_lobby()

    # Tick the match server
    send(pid, :tick)

    # Accept each user
    _tachyon_send(socket1, %{cmd: "c.matchmaking.accept", match_id: match_id})
    _tachyon_send(socket2, %{cmd: "c.matchmaking.accept", match_id: match_id})
    _tachyon_send(socket3, %{cmd: "c.matchmaking.accept", match_id: match_id})

    _tachyon_send(psocket1, %{cmd: "c.matchmaking.accept", match_id: match_id})
    _tachyon_send(psocket2, %{cmd: "c.matchmaking.accept", match_id: match_id})
    _tachyon_send(psocket3, %{cmd: "c.matchmaking.accept", match_id: match_id})
    :timer.sleep(100)

    [reply] = _tachyon_recv(socket1)
    assert reply["cmd"] == "s.lobby.joined"

    # Clear both sockets
    _tachyon_recv_until(socket1)

    # Wait for it to do everything
    :timer.sleep(1000)

    state = :sys.get_state(pid)

    assert state.user_ids |> Enum.sort() == [user1.id, user2.id, user3.id, puser1.id, puser2.id, puser3.id]
    assert state.pending_accepts == []
    assert state.accepted_users |> Enum.sort() == [user1.id, user2.id, user3.id, puser1.id, puser2.id, puser3.id]
    assert state.declined_users == []

    lobby = Battle.get_lobby(lobby_id)
    assert lobby.players |> Enum.sort() == [user1.id, user2.id, user3.id, puser1.id, puser2.id, puser3.id]

    assert Account.get_client_by_id(user1.id).team_number == 0
    assert Account.get_client_by_id(user2.id).team_number == 0
    assert Account.get_client_by_id(user3.id).team_number == 0

    assert Account.get_client_by_id(puser1.id).team_number == 1
    assert Account.get_client_by_id(puser2.id).team_number == 1
    assert Account.get_client_by_id(puser3.id).team_number == 1
  end

  test "Enough players but can't make teams with the groups", %{socket: _socket1, user: _user1} do
    # 3v3 queue, 3 groups of 2 players
    {:ok, queue} =
      Game.create_queue(%{
        "name" => "test_queue-3v3",
        "team_size" => 3,
        "team_count" => 2,
        "icon" => "fa-regular fa-home",
        "colour" => "#112233",
        "map_list" => ["map1"],
        "conditions" => %{},
        "settings" => %{
          "tick_interval" => 60_000
        }
      })

    %{socket: socket1_1, user: _user1_1} = tachyon_auth_setup()
    %{socket: socket1_2, user: user1_2} = tachyon_auth_setup()

    %{socket: socket2_1, user: _user2_1} = tachyon_auth_setup()
    %{socket: socket2_2, user: user2_2} = tachyon_auth_setup()

    %{socket: socket3_1, user: _user3_1} = tachyon_auth_setup()
    %{socket: socket3_2, user: user3_2} = tachyon_auth_setup()

    # Setup the parties
    _tachyon_send(socket1_1, %{"cmd" => "c.party.create"})
    [resp] = _tachyon_recv(socket1_1)
    assert resp["cmd"] == "s.party.added_to"
    party_id1 = resp["party"]["id"]

    _tachyon_send(socket1_1, %{"cmd" => "c.party.invite", "userid" => user1_2.id})
    _tachyon_send(socket1_2, %{"cmd" => "c.party.accept", "party_id" => party_id1})

    # Party 2
    _tachyon_send(socket2_1, %{"cmd" => "c.party.create"})
    [resp] = _tachyon_recv(socket2_1)
    assert resp["cmd"] == "s.party.added_to"
    party_id2 = resp["party"]["id"]

    _tachyon_send(socket2_1, %{"cmd" => "c.party.invite", "userid" => user2_2.id})
    _tachyon_send(socket2_2, %{"cmd" => "c.party.accept", "party_id" => party_id2})

    # Party 3
    _tachyon_send(socket3_1, %{"cmd" => "c.party.create"})
    [resp] = _tachyon_recv(socket3_1)
    assert resp["cmd"] == "s.party.added_to"
    party_id3 = resp["party"]["id"]

    _tachyon_send(socket3_1, %{"cmd" => "c.party.invite", "userid" => user3_2.id})
    _tachyon_send(socket3_2, %{"cmd" => "c.party.accept", "party_id" => party_id3})

    # Now add them to the server
    _tachyon_send(socket1_1, %{cmd: "c.matchmaking.join_queue", queue_id: queue.id})
    _tachyon_send(socket2_1, %{cmd: "c.matchmaking.join_queue", queue_id: queue.id})
    _tachyon_send(socket3_1, %{cmd: "c.matchmaking.join_queue", queue_id: queue.id})

    pid = Matchmaking.get_queue_wait_pid(queue.id)
    state = :sys.get_state(pid)
    assert Enum.count(state.buckets[17]) == 3
    assert state.groups_map |> Map.keys |> Enum.sort == Enum.sort([party_id1, party_id2, party_id3])

    send(pid, :tick)

    state = :sys.get_state(pid)
    assert Enum.count(state.buckets[17]) == 3
    assert state.groups_map |> Map.keys |> Enum.sort == Enum.sort([party_id1, party_id2, party_id3])
  end

  test "Group bigger than max teamsize", %{socket: socket1, user: _user1} do
    {:ok, queue} =
      Game.create_queue(%{
        "name" => "test_queue-1v1",
        "team_size" => 1,
        "team_count" => 2,
        "icon" => "fa-regular fa-home",
        "colour" => "#112233",
        "map_list" => ["map1"],
        "conditions" => %{},
        "settings" => %{
          "tick_interval" => 60_000
        }
      })

    %{socket: socket2, user: user2} = tachyon_auth_setup()

    # Setup the parties
    _tachyon_send(socket1, %{"cmd" => "c.party.create"})
    [resp] = _tachyon_recv(socket1)
    assert resp["cmd"] == "s.party.added_to"
    party_id = resp["party"]["id"]

    _tachyon_send(socket1, %{"cmd" => "c.party.invite", "userid" => user2.id})
    _tachyon_send(socket2, %{"cmd" => "c.party.accept", "party_id" => party_id})

    _tachyon_recv_until(socket1)

    # Attempt to join queue
    _tachyon_send(socket1, %{cmd: "c.matchmaking.join_queue", queue_id: queue.id})

    pid = Matchmaking.get_queue_wait_pid(queue.id)
    state = :sys.get_state(pid)
    refute state.groups_map |> Map.has_key?(party_id)

    [reply] = _tachyon_recv(socket1)
    assert reply == %{
      "cmd" => "s.matchmaking.join_queue",
      "queue_id" => queue.id,
      "result" => "failure",
      "reason" => "Group is larger than the queue team size"
    }
  end

  test "Test where there are multiple viable matches and it actually identifies the best one", %{socket: socket1, user: user1} do
    {:ok, queue} =
      Game.create_queue(%{
        "name" => "test_queue-1v1",
        "team_size" => 1,
        "team_count" => 2,
        "icon" => "fa-regular fa-home",
        "colour" => "#112233",
        "map_list" => ["map1"],
        "conditions" => %{},
        "settings" => %{
          "tick_interval" => 60_000
        }
      })

    %{socket: socket2, user: user2} = tachyon_auth_setup()
    %{socket: socket3, user: user3} = tachyon_auth_setup()

    rating_type_id = MatchRatingLib.rating_type_name_lookup()["Duel"]
    # The solo players should be significantly higher rated than the party
    make_rating(user1.id, rating_type_id, 23)
    make_rating(user2.id, rating_type_id, 25)
    make_rating(user3.id, rating_type_id, 26)

    pid = Matchmaking.get_queue_wait_pid(queue.id)
    state = :sys.get_state(pid)
    assert state.groups_map == %{}
    assert state.buckets == %{}

    group1 = user1.id
      |> Matchmaking.make_group_from_userid(queue)
      |> Map.merge(%{
        bucket: 30,
        search_distance: 5
      })

    group2 = user2.id
      |> Matchmaking.make_group_from_userid(queue)
      |> Map.merge(%{
        bucket: 25,
        search_distance: 0
      })

    group3 = user3.id
      |> Matchmaking.make_group_from_userid(queue)
      |> Map.merge(%{
        bucket: 24,
        search_distance: 1
      })

    Matchmaking.cast_queue_wait(queue.id, {:re_add_group, group1})
    Matchmaking.cast_queue_wait(queue.id, {:re_add_group, group2})
    Matchmaking.cast_queue_wait(queue.id, {:re_add_group, group3})

    state = :sys.get_state(pid)
    assert state.groups_map |> Map.keys |> Enum.sort == [user1.id, user2.id, user3.id]
    assert state.buckets[25] |> Enum.sort == [user1.id, user2.id, user3.id]

    # Re-add group 1 to ensure we can't duplicate
    Matchmaking.cast_queue_wait(queue.id, {:re_add_group, group1})

    state = :sys.get_state(pid)
    assert state.groups_map |> Map.keys |> Enum.sort == [user1.id, user2.id, user3.id]
    assert state.buckets[25] |> Enum.sort == [user1.id, user2.id, user3.id]

    # Clear sockets
    _tachyon_recv_until(socket1)
    _tachyon_recv_until(socket2)
    _tachyon_recv_until(socket3)

    send(pid, :tick)
    reply1 = _tachyon_recv(socket1)
    assert reply1 == :timeout

    reply2 = _tachyon_recv(socket2)
    refute reply2 == :timeout

    reply3 = _tachyon_recv(socket3)
    refute reply3 == :timeout
  end

  test "Party members change, group leaves the queue", %{socket: socket1, user: _user1} do
    {:ok, queue} =
      Game.create_queue(%{
        "name" => "test_queue-1v1",
        "team_size" => 3,
        "team_count" => 2,
        "icon" => "fa-regular fa-home",
        "colour" => "#112233",
        "map_list" => ["map1"],
        "conditions" => %{},
        "settings" => %{
          "tick_interval" => 60_000
        }
      })

    %{socket: socket2, user: user2} = tachyon_auth_setup()

    # Setup the parties
    _tachyon_send(socket1, %{"cmd" => "c.party.create"})
    [resp] = _tachyon_recv(socket1)
    assert resp["cmd"] == "s.party.added_to"
    party_id = resp["party"]["id"]

    _tachyon_send(socket1, %{"cmd" => "c.party.invite", "userid" => user2.id})
    _tachyon_send(socket2, %{"cmd" => "c.party.accept", "party_id" => party_id})

    _tachyon_recv_until(socket1)

    # Attempt to join queue
    _tachyon_send(socket1, %{cmd: "c.matchmaking.join_queue", queue_id: queue.id})

    pid = Matchmaking.get_queue_wait_pid(queue.id)
    state = :sys.get_state(pid)
    assert state.groups_map |> Map.has_key?(party_id)

    [reply] = _tachyon_recv(socket1)
    assert reply == %{
      "cmd" => "s.matchmaking.join_queue",
      "queue_id" => queue.id,
      "result" => "success"
    }

    # Ensure the queue is listed as part of the party
    party = Account.get_party(party_id)
    assert party.queues == [queue.id]

    # Now leave the party
    _tachyon_send(socket2, %{cmd: "c.party.leave"})
    party = Account.get_party(party_id)
    refute party.members |> Enum.member?(user2.id)

    # Ensure the party is removed from the queue
    state = :sys.get_state(pid)
    refute state.groups_map |> Map.has_key?(party_id)

    # and the party no longer lists itself as being in the queue
    party = Account.get_party(party_id)
    assert party.queues == []

    # Now test if someone joins the party it also removes them
    _tachyon_recv_until(socket1)
    _tachyon_send(socket1, %{cmd: "c.matchmaking.join_queue", queue_id: queue.id})

    state = :sys.get_state(pid)
    assert state.groups_map |> Map.has_key?(party_id)

    [reply] = _tachyon_recv(socket1)
    assert reply == %{
      "cmd" => "s.matchmaking.join_queue",
      "queue_id" => queue.id,
      "result" => "success"
    }

    _tachyon_send(socket1, %{"cmd" => "c.party.invite", "userid" => user2.id})
    _tachyon_send(socket2, %{"cmd" => "c.party.accept", "party_id" => party_id})

    # Ensure the party is removed from the queue
    state = :sys.get_state(pid)
    refute state.groups_map |> Map.has_key?(party_id)

    # and the party no longer lists itself as being in the queue
    party = Account.get_party(party_id)
    assert party.queues == []
  end

  test "Test it works when not sending out invites" do
    # There is a setting to not require an invite accept/decline, all
    # the other tests assume it to be set to true, we need to test when
    # it is set to fals
    flunk "Not done"
  end

  test "Moderated players can't do matchmaking" do
    # Ensure a person can't circumvent it by being a member of a party
    flunk "Not done"
  end
end
