defmodule Teiserver.Player.SessionTest do
  alias ExUnit.Callbacks
  alias Teiserver.AssetFixtures
  alias Teiserver.Cluster
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.Matchmaking.QueueServer
  alias Teiserver.Player
  alias Teiserver.Player.Session
  alias Teiserver.Player.SessionSupervisor
  alias Teiserver.Player.Types, as: PT
  alias Teiserver.Support.ClusterHelpers
  alias Teiserver.Support.Polling
  alias Teiserver.Support.Tachyon.Matchmaking, as: SupportMM
  alias Teiserver.Support.TaggedEcho
  alias Teiserver.Tachyon, as: TachyonLib
  alias Teiserver.TachyonLobby
  alias Teiserver.TachyonLobby.Registry, as: LobbyRegistry

  use Teiserver.DataCase, async: false

  @moduletag :tachyon

  setup_all do
    {_out, 0} = System.cmd("epmd", ["-daemon"], env: [])
    Node.start(:origin, name_domain: :shortnames, hidden: false)
    :ok
  end

  defp setup_void_session do
    user = GeneralTestLib.make_user(%{"roles" => ["Verified"]})
    {:ok, sess_pid} = SessionSupervisor.start_session(user)

    {:ok, fake_conn} =
      Supervisor.child_spec({Task, fn -> :timer.sleep(:infinity) end}, id: {:fake, user.id})
      |> Callbacks.start_supervised()

    Session.replace_connection(sess_pid, fake_conn)
    %{user: user, sess_pid: sess_pid, fake_conn: fake_conn}
  end

  defp setup_forwarded_session(tag) do
    ctx = setup_void_session()
    {:ok, echo_pid} = TaggedEcho.start(tag)
    Session.replace_connection(ctx.sess_pid, echo_pid)

    Map.put(ctx, :echo_pid, echo_pid)
    |> Map.delete(:fake_conn)
  end

  def setup_session(_context) do
    {:ok, setup_void_session()}
  end

  def setup_config(_context) do
    TachyonLib.enable_state_restoration()
    Callbacks.on_exit(fn -> TachyonLib.disable_state_restoration() end)
  end

  defp disconnect(fake_conn) do
    conn_ref = Process.monitor(fake_conn)
    Process.exit(fake_conn, :kill)
    assert_receive {:DOWN, ^conn_ref, :process, _, _}
  end

  defp start_battle(user_id) do
    {:ok, fake_battle_pid} = Task.start(:timer, :sleep, [:infinity])
    lobby_id = "lobby-id"

    {:ok, _fake_lobby_pid} =
      Task.start_link(fn ->
        LobbyRegistry.register(lobby_id)

        receive do
          {_pid, from, _join_msg} ->
            resp = {:ok, self(), %{id: lobby_id}}
            :gen_statem.reply(from, resp)
        end

        :timer.sleep(:infinity)
      end)

    Polling.poll_until_some(fn -> TachyonLobby.lookup(lobby_id) end)

    {:ok, _details} = Session.lobby_join(user_id, lobby_id)

    start_data = %{
      ips: ["127.0.0.1"],
      port: 1234,
      engine: %{version: "v1"},
      game: %{spring_name: "game"},
      map: %{spring_name: "map"}
    }

    Session.lobby_join_battle(user_id, {"battle-id", fake_battle_pid}, start_data, "password")
    fake_battle_pid
  end

  describe "user updates" do
    setup [:setup_session]

    test "ignore updates if not subscribed", %{sess_pid: sess_pid} do
      send(sess_pid, %{
        channel: "tachyon:user:123",
        user_id: 123,
        event: :user_updated,
        state: :irrelevant
      })

      refute_receive _message
    end
  end

  describe "connection timeout" do
    setup [:setup_session]

    test "session stops when timed out and not in battle",
         %{sess_pid: sess_pid, fake_conn: fake_conn} do
      ref = Process.monitor(sess_pid)
      disconnect(fake_conn)
      Session.trigger_connection_timeout(sess_pid)
      assert_receive {:DOWN, ^ref, :process, _, _}
    end

    test "session survives when player disconnects during battle",
         %{sess_pid: sess_pid, user: user, fake_conn: fake_conn} do
      ref = Process.monitor(sess_pid)
      _fake_battle = start_battle(user.id)
      disconnect(fake_conn)
      Session.trigger_connection_timeout(sess_pid)
      refute_receive {:DOWN, ^ref, :process, _, _}
    end

    test "session stops after battle ends and player is still disconnected",
         %{sess_pid: sess_pid, user: user, fake_conn: fake_conn} do
      fake_battle = start_battle(user.id)
      disconnect(fake_conn)

      sess_ref = Process.monitor(sess_pid)
      battle_ref = Process.monitor(fake_battle)
      Process.exit(fake_battle, :kill)
      assert_receive {:DOWN, ^battle_ref, :process, _, _}

      Polling.poll_until(
        fn -> Session.conn_state(user.id) end,
        fn state -> state == :reconnecting end
      )

      Session.trigger_connection_timeout(sess_pid)
      assert_receive {:DOWN, ^sess_ref, :process, _, _}
    end

    test "session survives when player reconnects before battle ends",
         %{sess_pid: sess_pid, user: user, fake_conn: fake_conn} do
      ref = Process.monitor(sess_pid)
      _fake_battle = start_battle(user.id)
      disconnect(fake_conn)

      {:ok, new_conn} = Task.start(:timer, :sleep, [:infinity])
      Session.replace_connection(sess_pid, new_conn)

      Session.trigger_connection_timeout(sess_pid)
      refute_receive {:DOWN, ^ref, :process, _, _}
      assert :connected == Session.conn_state(user.id)
    end

    test "stale connection timeout from before battle does not kill session",
         %{sess_pid: sess_pid, user: user, fake_conn: fake_conn} do
      ref = Process.monitor(sess_pid)
      disconnect(fake_conn)

      {:ok, new_conn} = Task.start(:timer, :sleep, [:infinity])
      Session.replace_connection(sess_pid, new_conn)

      _fake_battle = start_battle(user.id)
      disconnect(new_conn)

      Session.trigger_connection_timeout(sess_pid)
      refute_receive {:DOWN, ^ref, :process, _, _}
    end
  end

  describe "lobby and matchmaking" do
    test "party cancel mm can still requeue after" do
      ctx1 = setup_forwarded_session(:user1)
      ctx2 = setup_forwarded_session(:user2)

      other_ctx = [setup_void_session(), setup_void_session()]

      # we want to trigger a cancel event
      queue_settings =
        QueueServer.default_settings()
        |> Map.put(:pairing_timeout, 1)

      queue_ctx =
        %{team_size: 2, settings: queue_settings}
        |> SupportMM.queue_attrs()
        |> SupportMM.start_queue()

      {:ok, party} = Session.create_party(ctx1.user.id)
      :ok = Session.invite_to_party(ctx1.user.id, ctx2.user.id)
      :ok = Session.accept_invite_to_party(ctx2.user.id, party.id)

      :ok = Session.join_queues(ctx1.user.id, [{queue_ctx.id, queue_ctx.version}])
      assert_receive {:user2, {:matchmaking, {:queues_joined, _queues}}}

      Enum.each(other_ctx, fn ctx ->
        :ok = Session.join_queues(ctx.user.id, [{queue_ctx.id, queue_ctx.version}])
      end)

      SupportMM.match_players(queue_ctx.pid)
      assert_receive {:user1, {:matchmaking, {:notify_found, _queue, _timeout}}}
      assert_receive {:user2, {:matchmaking, {:notify_found, _queue, _timeout}}}

      assert_receive {:user1, {:matchmaking, {:cancelled, :timeout}}}

      :ok = Session.join_queues(ctx1.user.id, [{queue_ctx.id, queue_ctx.version}])
      assert_receive {:user2, {:matchmaking, {:queues_joined, _queues}}}
    end
  end

  describe "restore from snapshots" do
    setup [:setup_session, :setup_config]

    test "can restart a session after shutdown", %{user: user, sess_pid: sess_pid} do
      TachyonLib.restart_system()
      Polling.poll_until(fn -> nil end, fn _result -> not Process.alive?(sess_pid) end)

      Polling.poll_until_some(fn -> Player.lookup_session(user.id) end)
    end
  end

  defp setup_assets(_ctx) do
    game = AssetFixtures.create_game(%{name: "test-lobby-game", in_matchmaking: true})

    engine =
      AssetFixtures.create_engine(%{name: "test-lobby-engine", in_matchmaking: true})

    {:ok, game: game, engine: engine}
  end

  describe "lobby cluster" do
    setup [:setup_session, :setup_assets]

    test "track lobbies across replica", ctx do
      {_server_ref, peer} = ClusterHelpers.start_node(:peer1)
      Session.replace_connection(ctx.sess_pid, self())
      start_params = %PT.LobbyStartParams{name: "test", map_name: "Aurelia", ally_team_config: []}

      details =
        Stream.repeatedly(fn ->
          {:ok, details} = Session.create_lobby(ctx.user.id, start_params)

          # force a lobby on the replica for this test
          if TachyonLobby.routing_key(details.id) |> Cluster.primary?() do
            :ok = Session.lobby_leave(ctx.user.id)
            nil
          else
            details
          end
        end)
        |> Stream.reject(&is_nil/1)
        |> Enum.at(0)

      Node.disconnect(peer)
      refute_receive {:lobby, _id, {:left, _reason}}

      TachyonLobby.lookup(details.id) |> Process.exit(:kill)
      assert_receive {:lobby, _id, {:left, _reason}}
    end
  end
end
