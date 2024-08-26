defmodule TeiserverWeb.Tachyon.SessionTest do
  use TeiserverWeb.ConnCase
  alias WebsocketSyncClient, as: WSC
  alias Teiserver.Support.Tachyon
  import Teiserver.Support.Tachyon, only: [poll_until_some: 1, poll_until: 2]
  alias Teiserver.Player

  setup _context do
    user = Central.Helpers.GeneralTestLib.make_user(%{"data" => %{"roles" => ["Verified"]}})
    %{client: client, token: token} = Tachyon.connect(user)

    on_exit(fn -> WSC.disconnect(client) end)
    {:ok, user: user, client: client, token: token}
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

  test "session is restarted if player still connected", %{user: user, client: client} do
    sess_pid = poll_until_some(fn -> Player.SessionRegistry.lookup(user.id) end)
    Player.monitor_session(user.id)
    Process.exit(sess_pid, :please_die)
    assert_receive({:DOWN, _, :process, _, _})

    poll_until(
      fn -> Player.SessionRegistry.lookup(user.id) end,
      fn x -> x != sess_pid end
    )

    # make sure the existing client is still connected
    WSC.send_message(client, {:text, "test_ping"})
    assert {:ok, {:text, "test_pong"}} == WSC.recv(client)
  end

  test "existing connection is terminated when a new one comes in", %{
    client: client,
    token: token
  } do
    ensure_connected(client)
    opts = Tachyon.connect_options(token)
    {:ok, client2} = WSC.connect(Tachyon.tachyon_url(), opts)
    ensure_connected(client2)
    WSC.send_message(client, {:text, "test_ping"})
    assert {:error, :disconnected} == WSC.recv(client)
  end

  test "connection state for never seen before" do
    assert :disconnected == Player.conn_state(-123_489)
  end

  defp ensure_connected(client) do
    WSC.send_message(client, {:text, "test_ping"})
    assert {:ok, {:text, "test_pong"}} == WSC.recv(client)
  end
end
