defmodule Teiserver.Player.SessionTest do
  alias ExUnit.Callbacks
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.Helpers.MonitorCollection, as: MC
  alias Teiserver.Player
  alias Teiserver.Player.Session
  alias Teiserver.Player.SessionSupervisor
  alias Teiserver.Support.Polling
  alias Teiserver.Tachyon, as: TachyonLib

  use Teiserver.DataCase, async: false

  @moduletag :tachyon

  def setup_session(_context) do
    user = GeneralTestLib.make_user(%{"roles" => ["Verified"]})
    {:ok, sess_pid} = SessionSupervisor.start_session(user)
    {:ok, fake_conn} = Task.start(:timer, :sleep, [:infinity])
    Session.replace_connection(sess_pid, fake_conn)
    {:ok, user: user, sess_pid: sess_pid, fake_conn: fake_conn}
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

  defp start_battle(sess_pid, user_id) do
    {:ok, fake_battle} = Task.start(:timer, :sleep, [:infinity])
    {:ok, fake_room} = Task.start(:timer, :sleep, [:infinity])

    :sys.replace_state(sess_pid, fn state ->
      monitors = MC.monitor(state.monitors, fake_room, :mm_room)

      %{
        state
        | matchmaking: {:pairing, %{readied: true, battle_password: "pw", room: fake_room}},
          monitors: monitors
      }
    end)

    Session.battle_start(user_id, {"battle-id", fake_battle}, %{
      ips: ["127.0.0.1"],
      port: 1234,
      engine: %{version: "v1"},
      game: %{springName: "game"},
      map: %{springName: "map"}
    })

    fake_battle
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
      _fake_battle = start_battle(sess_pid, user.id)
      disconnect(fake_conn)
      Session.trigger_connection_timeout(sess_pid)
      refute_receive {:DOWN, ^ref, :process, _, _}
    end

    test "session stops after battle ends and player is still disconnected",
         %{sess_pid: sess_pid, user: user, fake_conn: fake_conn} do
      fake_battle = start_battle(sess_pid, user.id)
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
      _fake_battle = start_battle(sess_pid, user.id)
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

      _fake_battle = start_battle(sess_pid, user.id)
      disconnect(new_conn)

      Session.trigger_connection_timeout(sess_pid)
      refute_receive {:DOWN, ^ref, :process, _, _}
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
end
