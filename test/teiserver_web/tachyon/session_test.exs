defmodule TeiserverWeb.Tachyon.SessionTest do
  use TeiserverWeb.ConnCase
  alias WebsocketSyncClient, as: WSC
  alias Teiserver.Support.Tachyon
  import Teiserver.Support.Polling, only: [poll_until_some: 1, poll_until: 2]
  alias Teiserver.Player

  setup _context do
    Tachyon.setup_client()
  end

  test "session is spawned when player connects", %{user: user} do
    registered_pid = poll_until_some(fn -> Player.SessionRegistry.lookup(user.id) end)
    assert is_pid(registered_pid)
    assert :connected == Player.conn_state(user.id)
  end

  test "session persist after disconnection", %{user: user, client: client} do
    conn_pid = poll_until_some(fn -> Player.lookup_connection(user.id) end)
    assert :connected == Player.conn_state(user.id)
    Process.monitor(conn_pid)
    :ok = WSC.disconnect(client)
    assert_receive({:DOWN, _, :process, _, :normal})
    assert is_pid(Player.SessionRegistry.lookup(user.id))
    poll_until(fn -> Player.conn_state(user.id) end, &(&1 == :reconnecting))
  end

  test "player gets kicked out if session dies", %{user: user, client: client} do
    sess_pid = poll_until_some(fn -> Player.SessionRegistry.lookup(user.id) end)
    Player.monitor_session(user.id)
    Process.exit(sess_pid, :please_die)
    assert_receive({:DOWN, _, :process, _, _})

    # make sure the existing client has been disconnected
    assert {:error, :disconnected} == WSC.recv(client)
  end

  test "existing connection is terminated when a new one comes in", %{
    client: client,
    token: token
  } do
    opts = Tachyon.connect_options(token)
    {:ok, client2} = WSC.connect(Tachyon.tachyon_url(), opts)
    on_exit(fn -> Tachyon.cleanup_connection(client2, token) end)
    ensure_connected(client2)
    WSC.send_message(client, {:text, "test_ping"})
    assert {:error, :disconnected} == WSC.recv(client)
  end

  test "connection state for never seen before" do
    assert :disconnected == Player.conn_state(-123_489)
  end

  test "session dies after too long", %{client: client, user: user} do
    Tachyon.abrupt_disconnect!(client)
    assert {:error, :disconnected} = WSC.send_message(client, {:text, "test_ping"})
    sess_pid = Player.SessionRegistry.lookup(user.id)
    assert sess_pid != nil
    ref = Process.monitor(sess_pid)
    poll_until(fn -> Player.lookup_connection(user.id) end, &is_nil/1)
    send(sess_pid, :player_timeout)
    assert_receive({:DOWN, ^ref, :process, _, _}, 1000, "Session should have died")
  end

  defp ensure_connected(client) do
    WSC.send_message(client, {:text, "test_ping"})
    Tachyon.recv_message!(client)
    assert {:ok, {:text, "test_pong"}} == WSC.recv(client)
  end
end
