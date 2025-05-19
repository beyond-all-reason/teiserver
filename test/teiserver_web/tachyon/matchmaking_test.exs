defmodule Teiserver.Tachyon.MatchmakingTest do
  use TeiserverWeb.ConnCase
  alias Teiserver.Support.Tachyon
  alias Teiserver.Support.Polling
  alias Teiserver.OAuthFixtures
  alias Teiserver.Player
  alias Teiserver.AssetFixtures
  alias Teiserver.Asset
  alias Teiserver.Matchmaking.{QueueSupervisor, QueueServer}

  defp altair_attr(id),
    do: %{
      spring_name: "Altair Crossing Remake " <> id,
      display_name: "Altair Crossing",
      thumbnail_url: "https://www.beyondallreason.info/map/altair-crossing",
      matchmaking_queues: [id]
    }

  defp rosetta_attr(id),
    do: %{
      spring_name: "Rosetta " <> id,
      display_name: "Rosetta",
      thumbnail_url: "https://www.beyondallreason.info/map/rosetta",
      matchmaking_queues: [id]
    }

  defp map_attrs(id),
    do: [altair_attr(id), rosetta_attr(id)]

  defp map_names(id) do
    map_attrs(id)
    |> Enum.map(fn map -> %{"springName" => map.spring_name} end)
  end

  defp engine_versions(),
    do: [%{version: "105.1.1-2590-gb9462a0 bar"}, %{version: "100.2.1-2143-test bar"}]

  defp game_versions(),
    do: [
      %{spring_game: "Beyond All Reason test-26929-d709d32"},
      %{spring_game: "BAR test version"}
    ]

  defp engine_names() do
    engine_versions()
    |> Enum.map(fn engine -> %{"version" => engine.version} end)
  end

  defp game_names() do
    game_versions()
    |> Enum.map(fn game -> %{"springName" => game.spring_game} end)
  end

  defp setup_queue(context) when is_map(context) do
    setup_queue(1)
  end

  defp setup_queue(team_size) when is_integer(team_size) do
    id = UUID.uuid4()

    setup_maps(id)
    setup_queue(id, team_size)
  end

  defp setup_queue(id, team_size) do
    queue_attrs(id, team_size)
    |> mk_queue()
  end

  defp setup_maps(id) do
    map_attrs(id)
    |> Enum.each(&AssetFixtures.create_map/1)
  end

  defp queue_attrs(id, team_size) do
    maps =
      Asset.get_maps_for_queue(id)

    %{
      id: id,
      name: id,
      team_size: team_size,
      team_count: 2,
      settings: %{tick_interval_ms: :manual, max_distance: 15},
      engines: engine_versions(),
      games: game_versions(),
      maps: maps
    }
  end

  defp mk_queue(attrs) do
    Polling.poll_until_some(fn -> Process.whereis(QueueSupervisor) end)

    {:ok, pid} =
      QueueServer.init_state(attrs)
      |> QueueSupervisor.start_queue!()

    {:ok, queue_id: attrs.id, queue_pid: pid}
  end

  describe "list" do
    setup [{Tachyon, :setup_client}, :setup_queue]

    test "works", %{client: client, queue_id: q1v1_id} do
      {:ok, queue_id: q2v2_id, queue_pid: _} = setup_queue(2)

      resp = Tachyon.list_queues!(client)

      # Convert into a set since the order must not impact test result
      expected_playlists =
        MapSet.new([
          %{
            "id" => q1v1_id,
            "name" => q1v1_id,
            "numOfTeams" => 2,
            "teamSize" => 1,
            "ranked" => true,
            "engines" => engine_names(),
            "games" => game_names(),
            "maps" => map_names(q1v1_id)
          },
          %{
            "id" => q2v2_id,
            "name" => q2v2_id,
            "numOfTeams" => 2,
            "teamSize" => 2,
            "ranked" => true,
            "engines" => engine_names(),
            "games" => game_names(),
            "maps" => map_names(q2v2_id)
          }
        ])

      # Checking for subset because the response also contains default queues
      assert MapSet.subset?(expected_playlists, MapSet.new(resp["data"]["playlists"]))
    end

    test "empty map list", %{client: client} do
      :ok =
        Teiserver.Matchmaking.QueueServer.init_state(%{
          id: "mapless",
          name: "mapless",
          team_size: 1,
          team_count: 2,
          engines: engine_versions(),
          games: game_versions(),
          maps: []
        })
        |> start_queue()

      resp = Tachyon.list_queues!(client)

      expected_playlists =
        MapSet.new([
          %{
            "id" => "mapless",
            "name" => "mapless",
            "numOfTeams" => 2,
            "teamSize" => 1,
            "ranked" => true,
            "engines" => engine_names(),
            "games" => game_names(),
            "maps" => []
          }
        ])

      assert MapSet.subset?(expected_playlists, MapSet.new(resp["data"]["playlists"]))
    end
  end

  describe "joining queues" do
    setup [{Tachyon, :setup_client}, :setup_queue]

    test "works", %{client: client, queue_id: queue_id} do
      resp = Tachyon.join_queues!(client, [queue_id])
      assert %{"status" => "success"} = resp
      resp = Tachyon.join_queues!(client, [queue_id])
      assert %{"status" => "failed", "reason" => "already_queued"} = resp
    end

    test "multiple", %{client: client, queue_id: queue_id} do
      {:ok, queue_id: other_queue_id, queue_pid: _} = setup_queue(2)
      resp = Tachyon.join_queues!(client, [queue_id, other_queue_id])
      assert %{"status" => "success"} = resp
    end

    test "all or nothing", %{client: client, queue_id: queue_id} do
      resp = Tachyon.join_queues!(client, [queue_id, "lolnope that's not a queue"])
      assert %{"status" => "failed", "reason" => "invalid_queue_specified"} = resp
      resp = Tachyon.join_queues!(client, [queue_id])
      assert %{"status" => "success"} = resp
    end

    test "with disconnections", %{token: token, client: client, queue_id: queue_id} do
      %{"status" => "success"} = Tachyon.join_queues!(client, [queue_id])

      # clean disconnection removes user from queue
      Tachyon.disconnect!(client)
      client = Tachyon.connect(token)
      %{"status" => "success"} = Tachyon.join_queues!(client, [queue_id])

      # A crash doesn't remove the player from the queue
      Tachyon.abrupt_disconnect!(client)
      client = Tachyon.connect(token)

      %{"status" => "failed", "reason" => "already_queued"} =
        Tachyon.join_queues!(client, [queue_id])
    end

    test "too many player", %{client: client} do
      id = "emptyqueue"

      Teiserver.Matchmaking.QueueServer.init_state(%{
        id: id,
        name: id,
        team_size: 0,
        team_count: 2,
        engines: engine_versions(),
        games: game_versions(),
        maps: map_attrs(id)
      })
      |> start_queue()

      assert %{"status" => "failed", "reason" => "invalid_request"} =
               Tachyon.join_queues!(client, [id])
    end

    test "empty engines", %{client: client} do
      id = "emptyengines"

      :ok =
        Teiserver.Matchmaking.QueueServer.init_state(%{
          id: id,
          name: id,
          team_size: 1,
          team_count: 2,
          engines: [],
          games: game_versions(),
          maps: map_attrs(id)
        })
        |> start_queue()

      assert %{"status" => "failed", "reason" => "internal_error"} =
               Tachyon.join_queues!(client, [id])
    end

    test "empty games", %{client: client} do
      id = "emptygames"

      :ok =
        Teiserver.Matchmaking.QueueServer.init_state(%{
          id: id,
          name: id,
          team_size: 1,
          team_count: 2,
          engines: engine_versions(),
          games: [],
          maps: map_attrs(id)
        })
        |> start_queue()

      assert %{"status" => "failed", "reason" => "internal_error"} =
               Tachyon.join_queues!(client, [id])
    end

    test "empty maps", %{client: client} do
      id = "emptymaps"

      :ok =
        Teiserver.Matchmaking.QueueServer.init_state(%{
          id: id,
          name: id,
          team_size: 1,
          team_count: 2,
          engines: engine_versions(),
          games: game_versions(),
          maps: []
        })
        |> start_queue()

      assert %{"status" => "failed", "reason" => "internal_error"} =
               Tachyon.join_queues!(client, [id])
    end

    test "cancelled event when queue dies", %{
      client: client,
      queue_id: queue_id,
      queue_pid: queue_pid
    } do
      assert %{"status" => "success"} = Tachyon.join_queues!(client, [queue_id])
      Process.unlink(queue_pid)
      Process.exit(queue_pid, :kill)
      assert %{"commandId" => "matchmaking/cancelled"} = Tachyon.recv_message!(client)

      # can join again
      {:ok, queue_id: q2_id, queue_pid: _q2_pid} = setup_queue(1)
      assert %{"status" => "success"} = Tachyon.join_queues!(client, [q2_id])
    end
  end

  describe "interactions with assets" do
    setup [{Tachyon, :setup_client}, :setup_queue]

    test "cancelled event when engine version change", ctx do
      Process.unlink(ctx.queue_pid)
      assert %{"status" => "success"} = Tachyon.join_queues!(ctx.client, [ctx.queue_id])
      g2 = AssetFixtures.create_engine(%{name: "game1"})
      Teiserver.Asset.set_engine_matchmaking(g2.id)
      # when running many tests, or with --repeat-until-failure sometimes the
      # supervisors get restarted too many times without the sleep
      # I have no idea why a small sleep fixes it though :(
      :timer.sleep(5)
      assert %{"commandId" => "matchmaking/cancelled"} = Tachyon.recv_message!(ctx.client)
    end

    test "cancelled event when game version change", ctx do
      Process.unlink(ctx.queue_pid)
      assert %{"status" => "success"} = Tachyon.join_queues!(ctx.client, [ctx.queue_id])
      g2 = AssetFixtures.create_game(%{name: "game1"})
      Teiserver.Asset.set_game_matchmaking(g2.id)
      assert %{"commandId" => "matchmaking/cancelled"} = Tachyon.recv_message!(ctx.client)
    end
  end

  describe "leaving queues" do
    setup [{Tachyon, :setup_client}, :setup_queue]

    test "works", %{client: client, queue_id: queue_id} do
      assert %{"status" => "success"} = Tachyon.join_queues!(client, [queue_id])
      assert %{"status" => "success"} = Tachyon.leave_queues!(client)

      assert %{"commandId" => "matchmaking/cancelled", "data" => %{"reason" => "intentional"}} =
               Tachyon.recv_message!(client)

      assert %{"status" => "failed", "reason" => "not_queued"} =
               Tachyon.leave_queues!(client)
    end

    test "session timeout", %{client: client, queue_id: queue_id, user: user, token: token} do
      assert %{"status" => "success"} = Tachyon.join_queues!(client, [queue_id])
      Tachyon.abrupt_disconnect!(client)

      # also forcefully terminate the session, this simulates a player
      # crash without reconnection
      session_pid = Player.SessionRegistry.lookup(user.id)
      assert is_pid(session_pid)
      ref = Player.monitor_session(user.id)
      Process.exit(session_pid, :kill)

      assert_receive({:DOWN, ^ref, :process, _, _})

      # should have left the queue, so be able to rejoin
      client = Tachyon.connect(token)
      assert %{"status" => "success"} = Tachyon.join_queues!(client, [queue_id])
    end
  end

  describe "pairing" do
    defp setup_app(_context) do
      owner = Central.Helpers.GeneralTestLib.make_user(%{"data" => %{"roles" => ["Verified"]}})

      app =
        OAuthFixtures.app_attrs(owner.id)
        |> Map.put(:uid, UUID.uuid4())
        |> OAuthFixtures.create_app()

      {:ok, app: app}
    end

    defp setup_user(app) do
      user = Central.Helpers.GeneralTestLib.make_user(%{"data" => %{"roles" => ["Verified"]}})
      token = OAuthFixtures.token_attrs(user.id, app) |> OAuthFixtures.create_token()
      client = Tachyon.connect(token)
      {:ok, %{user: user, token: token, client: client}}
    end

    setup [:setup_queue, :setup_app]

    test "get found events", %{queue_id: queue_id, app: app, queue_pid: queue_pid} do
      {:ok, %{user: _user1, client: client1}} = setup_user(app)
      {:ok, %{user: _user2, client: client2}} = setup_user(app)
      assert %{"status" => "success"} = Tachyon.join_queues!(client1, [queue_id])
      assert %{"status" => "success"} = Tachyon.join_queues!(client2, [queue_id])
      send(queue_pid, :tick)

      Enum.each([client1, client2], fn client ->
        assert {:ok, resp} = Tachyon.recv_message(client, timeout: 10)

        assert %{
                 "commandId" => "matchmaking/found",
                 "data" => %{
                   "queueId" => ^queue_id
                 }
               } = resp
      end)

      # check that players aren't matched multiple times
      send(queue_pid, :tick)
      assert {:error, :timeout} = Tachyon.recv_message(client1, timeout: 10)
    end

    test "handle ready events", %{queue_id: queue_id, app: app, queue_pid: queue_pid} do
      {:ok, %{client: client1}} = setup_user(app)
      {:ok, %{client: client2}} = setup_user(app)
      assert %{"status" => "failed", "reason" => "no_match"} = Tachyon.matchmaking_ready!(client1)

      assert %{"status" => "success"} = Tachyon.join_queues!(client1, [queue_id])
      assert %{"status" => "success"} = Tachyon.join_queues!(client2, [queue_id])

      assert %{"status" => "failed", "reason" => "no_match"} = Tachyon.matchmaking_ready!(client1)

      send(queue_pid, :tick)

      assert {:ok, %{"commandId" => "matchmaking/found"}} = Tachyon.recv_message(client1)
      assert {:ok, %{"commandId" => "matchmaking/found"}} = Tachyon.recv_message(client2)

      assert %{"status" => "success"} = Tachyon.matchmaking_ready!(client1)
    end

    test "still considered in queue during pairing", %{
      queue_id: queue_id,
      app: app,
      queue_pid: queue_pid
    } do
      [client, _] = join_and_pair(app, queue_id, queue_pid, 2)
      resp = Tachyon.join_queues!(client, [queue_id])
      assert %{"status" => "failed", "reason" => "already_queued"} = resp
    end

    test "cancelled event if queue dies during pairing", ctx do
      [client1, client2] = join_and_pair(ctx.app, ctx.queue_id, ctx.queue_pid, 2)
      Process.unlink(ctx.queue_pid)
      Process.exit(ctx.queue_pid, :kill)

      assert %{"commandId" => "matchmaking/cancelled"} = Tachyon.recv_message!(client1)
      assert %{"commandId" => "matchmaking/cancelled"} = Tachyon.recv_message!(client2)
    end

    test "ready then leave triggers lost events", %{
      queue_id: queue_id,
      app: app,
      queue_pid: queue_pid
    } do
      [client1, client2] = join_and_pair(app, queue_id, queue_pid, 2)
      assert %{"status" => "success"} = Tachyon.matchmaking_ready!(client1)
      assert %{"commandId" => "matchmaking/foundUpdate"} = Tachyon.recv_message!(client1)
      assert %{"commandId" => "matchmaking/foundUpdate"} = Tachyon.recv_message!(client2)
      assert %{"status" => "success"} = Tachyon.leave_queues!(client1)
      assert %{"commandId" => "matchmaking/lost"} = Tachyon.recv_message!(client2)
    end

    test "back in queue if a player decline", %{
      queue_id: queue_id,
      app: app,
      queue_pid: queue_pid
    } do
      [client1, client2] = join_and_pair(app, queue_id, queue_pid, 2)
      assert %{"status" => "success"} = Tachyon.leave_queues!(client1)

      assert %{"commandId" => "matchmaking/lost"} = Tachyon.recv_message!(client2)

      assert %{"commandId" => "matchmaking/cancelled", "data" => %{"reason" => "intentional"}} =
               Tachyon.recv_message!(client1)

      assert %{"status" => "failed", "reason" => "already_queued"} =
               Tachyon.join_queues!(client2, [queue_id])

      assert %{"status" => "success"} = Tachyon.join_queues!(client1, [queue_id])

      # another tick should match them again
      send(queue_pid, :tick)

      assert {:ok, %{"commandId" => "matchmaking/found"}} = Tachyon.recv_message(client1)
      assert {:ok, %{"commandId" => "matchmaking/found"}} = Tachyon.recv_message(client2)
    end

    test "two pairings on different queues", %{app: app} do
      {:ok, queue_id: q1v1_id, queue_pid: q1v1_pid} = setup_queue(1)
      {:ok, queue_id: q2v2_id, queue_pid: q2v2_pid} = setup_queue(2)

      clients =
        Enum.map(1..5, fn _ ->
          {:ok, %{client: client}} = setup_user(app)
          client
        end)

      [c1, c2, c3, c4, c5] = clients

      for client <- Enum.take(clients, 3) do
        assert %{"status" => "success"} = Tachyon.join_queues!(client, [q2v2_id])
      end

      assert %{"status" => "success"} = Tachyon.join_queues!(c4, [q1v1_id])
      assert %{"status" => "success"} = Tachyon.join_queues!(c5, [q1v1_id, q2v2_id])

      send(q2v2_pid, :tick)

      for client <- [c1, c2, c3, c5] do
        assert {:ok, %{"commandId" => "matchmaking/found"}} = Tachyon.recv_message(client)
      end

      # getting paired should withdraw the player from a queue so that it doesn't
      # get 2 `found` events
      send(q1v1_pid, :tick)

      # a `found` event should be followed by a `lost` event, but it's not
      # 100% that the `found` event is sent at all
      case Tachyon.recv_message(c4, timeout: 5) do
        {:error, :timeout} ->
          nil

        {:ok, %{"commandId" => "matchmaking/found"}} ->
          assert {:ok, %{"commandId" => "matchmaking/lost"}} =
                   Tachyon.recv_message(c4, timeout: 5)
      end

      assert({:error, :timeout} = Tachyon.recv_message(c5, timeout: 3))
    end

    test "foundUpdate event", %{app: app} do
      {:ok, queue_id: q_id, queue_pid: q_pid} = setup_queue(2)

      clients =
        Enum.map(1..4, fn _ ->
          {:ok, %{client: client}} = setup_user(app)
          client
        end)

      for client <- clients do
        assert %{"status" => "success"} = Tachyon.join_queues!(client, [q_id])
      end

      send(q_pid, :tick)

      for client <- clients do
        assert {:ok, %{"commandId" => "matchmaking/found"}} = Tachyon.recv_message(client)
      end

      Enum.with_index(clients, 1)
      |> Enum.each(fn {client, current} ->
        Tachyon.matchmaking_ready!(client)

        Enum.each(clients, fn client -> assert_ready_update(client, current) end)
      end)
    end

    test "timeout puts ready players back in queue", %{app: app} do
      timeout_ms = 5
      uuid = UUID.uuid4()

      setup_maps(uuid)

      {:ok, queue_id: q_id, queue_pid: q_pid} =
        queue_attrs(uuid, 1)
        |> put_in([:settings, :pairing_timeout], timeout_ms)
        |> mk_queue()

      clients =
        Enum.map(1..2, fn _ ->
          {:ok, %{client: client}} = setup_user(app)
          client
        end)

      for client <- clients do
        assert %{"status" => "success"} = Tachyon.join_queues!(client, [q_id])
      end

      send(q_pid, :tick)

      for client <- clients do
        assert {:ok, %{"commandId" => "matchmaking/found"}} = Tachyon.recv_message(client)
      end

      [c1, c2] = clients
      Tachyon.matchmaking_ready!(c1)
      assert %{"commandId" => "matchmaking/foundUpdate"} = Tachyon.recv_message!(c1)
      assert %{"commandId" => "matchmaking/foundUpdate"} = Tachyon.recv_message!(c2)

      # TODO: c1 should get lost event and still be in the queue
      # c2 should get lost event but not be in the queue anymore
      assert %{"commandId" => "matchmaking/lost"} =
               Tachyon.recv_message!(c1, timeout: timeout_ms + 3)

      assert %{"commandId" => "matchmaking/lost"} =
               Tachyon.recv_message!(c2, timeout: timeout_ms + 3)

      assert %{"commandId" => "matchmaking/cancelled", "data" => %{"reason" => "ready_timeout"}} =
               Tachyon.recv_message!(c2, timeout: 2)

      assert %{"reason" => "already_queued"} = Tachyon.join_queues!(c1, [q_id])
      assert %{"status" => "success"} = Tachyon.join_queues!(c2, [q_id])
    end

    test "no autohost", %{app: app, queue_id: queue_id, queue_pid: queue_pid} do
      clients = join_and_pair(app, queue_id, queue_pid, 2)

      # slurp all the received messages, each client get a foundUpdate event for
      # every ready sent
      for client <- clients do
        assert %{"status" => "success"} = Tachyon.matchmaking_ready!(client)

        for c <- clients do
          assert %{"commandId" => "matchmaking/foundUpdate"} = Tachyon.recv_message!(c)
        end
      end

      for client <- clients do
        assert %{"commandId" => "matchmaking/lost"} = Tachyon.recv_message!(client)

        assert %{
                 "commandId" => "matchmaking/cancelled",
                 "data" => %{"reason" => "server_error", "details" => "no_host_available"}
               } =
                 Tachyon.recv_message!(client)
      end
    end
  end

  describe "join with autohost" do
    setup [{Tachyon, :setup_client}, :setup_app, :setup_queue, {Tachyon, :setup_autohost}]

    test "happy full path", %{
      app: app,
      queue_id: queue_id,
      queue_pid: queue_pid,
      autohost_client: autohost_client
    } do
      clients =
        join_and_pair(app, queue_id, queue_pid, 2)
        |> all_ready_up!()

      start_req = Tachyon.recv_message!(autohost_client)
      assert %{"commandId" => "autohost/start", "type" => "request", "data" => data} = start_req

      host_data = %{
        ips: ["127.0.0.1"],
        port: 48912
      }

      Tachyon.send_response(autohost_client, start_req, data: host_data)

      user_ids =
        for ally_team <- data["allyTeams"],
            team <- ally_team["teams"],
            player <- team["players"] do
          assert Map.has_key?(player, "name")
          assert Map.has_key?(player, "password")
          player["userId"]
        end

      assert Enum.count(user_ids) == 2

      for user_id <- user_ids do
        {user_id, _} = Integer.parse(user_id)
        assert is_pid(Player.SessionRegistry.lookup(user_id))
      end

      # Map will be randomly selected so we first check if the first client's map is in the map pool
      [first_client | rest_clients] = clients
      first_message = Tachyon.recv_message!(first_client)

      assert %{
               "commandId" => "battle/start",
               "data" => %{
                 "ip" => _ip,
                 "port" => _port,
                 "engine" => %{"version" => "105.1.1-2590-gb9462a0 bar"},
                 "game" => %{"springName" => "Beyond All Reason test-26929-d709d32"},
                 "map" => %{"springName" => spring_name}
               }
             } = first_message

      maps =
        map_attrs(queue_id)
        |> Enum.map(fn map -> map.spring_name end)

      assert spring_name in maps

      # and then if that the rest of clients have the same map
      for client <- rest_clients do
        assert %{
                 "commandId" => "battle/start",
                 "data" => %{
                   "ip" => _ip,
                   "port" => _port,
                   "engine" => %{"version" => "105.1.1-2590-gb9462a0 bar"},
                   "game" => %{"springName" => "Beyond All Reason test-26929-d709d32"},
                   "map" => %{"springName" => ^spring_name}
                 }
               } = Tachyon.recv_message!(client)
      end
    end

    test "autohost errors propagates to clients",
         %{
           app: app,
           queue_id: queue_id,
           queue_pid: queue_pid,
           autohost_client: autohost_client
         } do
      clients =
        join_and_pair(app, queue_id, queue_pid, 2)
        |> all_ready_up!()

      start_req = Tachyon.recv_message!(autohost_client)
      assert %{"commandId" => "autohost/start", "type" => "request", "data" => _data} = start_req

      resp_data = [reason: "engine_version_not_available"]
      assert :ok = Tachyon.send_response(autohost_client, start_req, resp_data)

      for client <- clients do
        assert %{"commandId" => "matchmaking/lost"} = Tachyon.recv_message!(client)

        assert %{
                 "commandId" => "matchmaking/cancelled",
                 "data" => %{
                   "reason" => "server_error",
                   "details" => "engine_version_not_available"
                 }
               } =
                 Tachyon.recv_message!(client)
      end
    end
  end

  defp join_and_pair(app, queue_id, queue_pid, number_of_player) do
    clients =
      Enum.map(1..number_of_player, fn _ ->
        {:ok, %{client: client}} = setup_user(app)
        assert %{"status" => "success"} = Tachyon.join_queues!(client, [queue_id])
        client
      end)

    send(queue_pid, :tick)

    Enum.each(clients, fn client ->
      assert {:ok, %{"commandId" => "matchmaking/found"}} = Tachyon.recv_message(client)
    end)

    clients
  end

  defp all_ready_up!(clients) do
    # slurp all the received messages, each client get a foundUpdate event for
    # every ready sent
    for client <- clients do
      assert %{"status" => "success"} = Tachyon.matchmaking_ready!(client)

      for c <- clients do
        assert %{"commandId" => "matchmaking/foundUpdate"} = Tachyon.recv_message!(c)
      end
    end

    clients
  end

  defp assert_ready_update(client, current) do
    assert {:ok,
            %{
              "commandId" => "matchmaking/foundUpdate",
              "data" => %{
                "readyCount" => ^current
              }
            }} = Tachyon.recv_message(client, timeout: 10)
  end

  defp start_queue(state) do
    {:ok, _pid} = QueueSupervisor.start_queue!(state)
    :ok
  end
end
