defmodule Teiserver.Matchmaking.MatchmakingTest do
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
          }
        ])

      assert MapSet.new(resp["data"]["playlists"]) == expected_playlists
    end
  end

  defp mk_queue(team_size) do
    alias Teiserver.Matchmaking.QueueServer
    id = UUID.uuid4()

    {:ok, pid} =
      QueueServer.init_state(%{
        id: id,
        name: id,
        team_size: team_size,
        team_count: 2,
        settings: %{tick_interval_ms: :manual, max_distance: 15}
      })
      |> QueueServer.start_link()

    {:ok, queue_id: id, queue_pid: pid}
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

    test "back in queue if a player decline", %{
      queue_id: queue_id,
      app: app,
      queue_pid: queue_pid
    } do
      [client1, client2] = join_and_pair(app, queue_id, queue_pid, 2)
      assert %{"status" => "success"} = Tachyon.leave_queues!(client1)

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
