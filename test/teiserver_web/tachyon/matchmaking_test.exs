defmodule Teiserver.Tachyon.MatchmakingTest do
  use TeiserverWeb.ConnCase
  alias Teiserver.Support.Tachyon
  alias Teiserver.OAuthFixtures
  alias Teiserver.Player

  describe "list" do
    setup {Tachyon, :setup_client}

    test "works", %{client: client} do
      resp = Tachyon.list_queues!(client)

      # convert into a set since the order must not impact test result
      expected_playlists =
        MapSet.new([
          %{
            "id" => "1v1",
            "name" => "Duel",
            "numOfTeams" => 2,
            "teamSize" => 1,
            "ranked" => true
          },
          %{
            "id" => "2v2",
            "name" => "2v2",
            "numOfTeams" => 2,
            "teamSize" => 2,
            "ranked" => true
          }
        ])

      assert MapSet.new(resp["data"]["playlists"]) == expected_playlists
    end
  end

  defp mk_queue_attrs(team_size) do
    id = UUID.uuid4()

    %{
      id: id,
      name: id,
      team_size: team_size,
      team_count: 2,
      settings: %{tick_interval_ms: :manual, max_distance: 15}
    }
  end

  defp mk_queue(team_size) when is_integer(team_size) do
    mk_queue(mk_queue_attrs(team_size))
  end

  defp mk_queue(attrs) do
    alias Teiserver.Matchmaking.QueueServer

    {:ok, pid} =
      QueueServer.init_state(attrs)
      |> QueueServer.start_link()

    {:ok, queue_id: attrs.id, queue_pid: pid}
  end

  defp setup_queue(_context) do
    mk_queue(1)
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
      {:ok, queue_id: other_queue_id, queue_pid: _} = setup_queue(nil)
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

      {:ok, _} =
        Teiserver.Matchmaking.QueueServer.init_state(%{
          id: id,
          name: id,
          team_size: 0,
          team_count: 2
        })
        |> Teiserver.Matchmaking.QueueServer.start_link()

      assert %{"status" => "failed", "reason" => "invalid_request"} =
               Tachyon.join_queues!(client, [id])
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

      assert {:ok, %{"status" => "success", "commandId" => "matchmaking/found"}} =
               Tachyon.recv_message(client1)

      assert {:ok, %{"status" => "success", "commandId" => "matchmaking/found"}} =
               Tachyon.recv_message(client2)

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

    test "ready then leave triggers lost events", %{
      queue_id: queue_id,
      app: app,
      queue_pid: queue_pid
    } do
      [client1, client2] = join_and_pair(app, queue_id, queue_pid, 2)
      assert %{"status" => "success"} = Tachyon.matchmaking_ready!(client1)
      assert %{"status" => "success"} = Tachyon.leave_queues!(client1)
      assert %{"commandId" => "matchmaking/foundUpdate"} = Tachyon.recv_message!(client2)
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

      assert {:ok, %{"status" => "success", "commandId" => "matchmaking/found"}} =
               Tachyon.recv_message(client1)

      assert {:ok, %{"status" => "success", "commandId" => "matchmaking/found"}} =
               Tachyon.recv_message(client2)
    end

    test "two pairings on different queues", %{app: app} do
      {:ok, queue_id: q1v1_id, queue_pid: q1v1_pid} = mk_queue(1)
      {:ok, queue_id: q2v2_id, queue_pid: q2v2_pid} = mk_queue(2)

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
        assert {:ok, %{"status" => "success", "commandId" => "matchmaking/found"}} =
                 Tachyon.recv_message(client)
      end

      # getting paired should withdraw the player from a queue so that it doesn't
      # get 2 `found` events
      send(q1v1_pid, :tick)

      # a `found` event should be followed by a `lost` event, but it's not
      # 100% that the `found` event is sent at all
      case Tachyon.recv_message(c4, timeout: 5) do
        {:error, :timeout} ->
          nil

        {:ok, %{"status" => "success", "commandId" => "matchmaking/found"}} ->
          assert {:ok, %{"status" => "success", "commandId" => "matchmaking/lost"}} =
                   Tachyon.recv_message(c4, timeout: 5)
      end

      assert({:error, :timeout} = Tachyon.recv_message(c5, timeout: 3))
    end

    test "foundUpdate event", %{app: app} do
      {:ok, queue_id: q_id, queue_pid: q_pid} = mk_queue(2)

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
        assert {:ok, %{"status" => "success", "commandId" => "matchmaking/found"}} =
                 Tachyon.recv_message(client)
      end

      Enum.with_index(clients, 1)
      |> Enum.each(fn {client, current} ->
        Tachyon.matchmaking_ready!(client)

        Enum.each(clients, fn client -> assert_ready_update(client, current) end)
      end)
    end

    test "timeout puts ready players back in queue", %{app: app} do
      timeout_ms = 5

      {:ok, queue_id: q_id, queue_pid: q_pid} =
        mk_queue_attrs(1)
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
        assert {:ok, %{"status" => "success", "commandId" => "matchmaking/found"}} =
                 Tachyon.recv_message(client)
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

  def setup_autohost(context) do
    autohost = Teiserver.BotFixtures.create_bot()

    token =
      OAuthFixtures.token_attrs(nil, context.app)
      |> Map.drop([:owner_id])
      |> Map.put(:bot_id, autohost.id)
      |> OAuthFixtures.create_token()

    client = Tachyon.connect_autohost!(token, 10, 0)
    {:ok, autohost: autohost, autohost_client: client}
  end

  describe "join with autohost" do
    setup [{Tachyon, :setup_client}, :setup_app, :setup_queue, :setup_autohost]

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
          # TODO: actually run json schema validation on the payloadd instead of that
          assert Map.has_key?(player, "name")
          assert Map.has_key?(player, "password")
          player["userId"]
        end

      assert Enum.count(user_ids) == 2

      for user_id <- user_ids do
        {user_id, _} = Integer.parse(user_id)
        assert is_pid(Player.SessionRegistry.lookup(user_id))
      end

      for client <- clients do
        # TODO: same, json schema validation here
        assert %{"commandId" => "battle/start", "data" => %{"ip" => _ip, "port" => _port}} =
                 Tachyon.recv_message!(client)
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
      assert {:ok, %{"status" => "success", "commandId" => "matchmaking/found"}} =
               Tachyon.recv_message(client)
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
end
