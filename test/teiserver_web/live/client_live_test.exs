defmodule TeiserverWeb.Live.ClientTest do
  @moduledoc false

  alias Teiserver.Account.ClientIndexThrottle
  alias Teiserver.Client
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.TeiserverTestLib

  use TeiserverWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TeiserverTestLib, only: [_send_raw: 2, teiserver_seed: 0]

  setup do
    {:ok, setup_result} =
      TeiserverTestLib.admin_permissions()
      |> GeneralTestLib.conn_setup()
      |> TeiserverTestLib.conn_setup()

    throttle_pid = start_link_supervised!(ClientIndexThrottle)

    {:ok, [throttle_pid: throttle_pid] ++ setup_result}
  end

  describe "client live" do
    # Clint login of user2 is not detected
    test "index", %{conn: conn, throttle_pid: throttle_pid} do
      {:ok, view, _html} = live(conn, "/teiserver/admin/client")

      # Sadly because other clients can still be logged in after
      # their tests we can't actually test this bit...
      # assert html =~ "No clients found"

      # Sleeps are to allow for the throttle server to update us

      {:ok, server_context} = TeiserverTestLib.start_spring_server()

      # Time to add a client
      %{socket: socket1, user: user1} = TeiserverTestLib.auth_setup(server_context)

      tick_and_wait(throttle_pid)
      html = render(view)
      assert html =~ "Clients - "
      assert html =~ "#{user1.name}"

      # Another
      %{socket: socket2, user: user2} = TeiserverTestLib.auth_setup(server_context)
      tick_and_wait(throttle_pid)
      html = render(view)
      assert html =~ "Clients - "
      assert html =~ "#{user1.name}"
      assert html =~ "#{user2.name}"

      # User 2 logs out
      _send_raw(socket2, "EXIT\n")
      tick_and_wait(throttle_pid)
      html = render(view)
      assert html =~ "Clients - "
      assert html =~ "#{user1.name}"
      refute html =~ "#{user2.name}"

      # And now user 1 too
      _send_raw(socket1, "EXIT\n")
      tick_and_wait(throttle_pid)
      html = render(view)
      # assert html =~ "No clients found"
      refute html =~ "#{user1.name}"
      refute html =~ "#{user2.name}"
    end

    # Failing partly due to the flash not being displayed but also
    # due to telemetry events not being able to be done correctly
    test "show - valid client", %{conn: conn} do
      teiserver_seed()

      {:ok, server_context} = TeiserverTestLib.start_spring_server()
      %{socket: _socket, user: user} = TeiserverTestLib.auth_setup(server_context)
      # client = Client.get_client_by_id(user.id)

      {:ok, _view, html} = live(conn, "/teiserver/admin/client/#{user.id}")
      assert html =~ user.name
      assert html =~ "Bot: false"
      assert html =~ "Moderator: false"
      # The nil is on a newline with padding so don't worry about it
      assert html =~ "Battle:"

      # Previously we would redirect if the user was logged out but this
      # may no longer be the case. The rest of the test is still valid
      # # Log out the user
      # # this part is failing because the liveview subscribes to old pubsubs
      # _send_raw(socket, "EXIT\n")
      # assert_redirect(view, "/teiserver/admin/client", 250)
    end

    test "show - no client", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/teiserver/admin/client"}}} =
               live(conn, "/teiserver/admin/client/0")
    end

    test "force disconnect client", %{conn: conn} do
      {:ok, server_context} = TeiserverTestLib.start_spring_server()
      %{user: user} = TeiserverTestLib.auth_setup(server_context)

      {:ok, view, _html} = live(conn, "/teiserver/admin/client/#{user.id}")
      assert Client.get_client_by_id(user.id) != nil

      render_click(view, "force-reconnect", %{})
      assert_redirect(view, "/teiserver/admin/client", 250)

      assert Client.get_client_by_id(user.id) == nil
    end
  end

  # We send a tick to the throttle server and wait 50ms to allow
  # a PubSub broadcast to be sent to the liveview at which stage
  # we can proceed
  defp tick_and_wait(throttle_pid) do
    send(throttle_pid, :tick)
    :timer.sleep(50)
  end
end
