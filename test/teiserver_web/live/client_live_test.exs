defmodule TeiserverWeb.Live.ClientTest do
  @moduledoc false
  use TeiserverWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias Teiserver.Client
  alias Central.Helpers.GeneralTestLib
  alias Teiserver.TeiserverTestLib
  import Teiserver.TeiserverTestLib, only: [_send_raw: 2]

  setup do
    GeneralTestLib.conn_setup(Teiserver.TeiserverTestLib.admin_permissions())
    |> TeiserverTestLib.conn_setup()
  end

  @sleep_time 2100

  describe "client live" do
    @tag :needs_attention
    test "index", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/teiserver/admin/client")

      # Sadly because other clients can still be logged in after their tests we can't actually test this bit...
      # assert html =~ "No clients found"

      # Sleeps are to allow for the throttle server to update us

      {:ok, server_context} = Teiserver.TeiserverTestLib.start_spring_server()

      # Time to add a client
      %{socket: socket1, user: user1} = TeiserverTestLib.auth_setup(server_context)

      :timer.sleep(@sleep_time)
      html = render(view)
      assert html =~ "Clients - "
      assert html =~ "#{user1.name}"

      # Another
      %{socket: socket2, user: user2} = TeiserverTestLib.auth_setup(server_context)
      :timer.sleep(@sleep_time)
      html = render(view)
      assert html =~ "Clients - "
      assert html =~ "#{user1.name}"
      assert html =~ "#{user2.name}"

      # User 2 logs out
      _send_raw(socket2, "EXIT\n")
      :timer.sleep(@sleep_time)
      html = render(view)
      assert html =~ "Clients - "
      assert html =~ "#{user1.name}"
      refute html =~ "#{user2.name}"

      # And now user 1 too
      _send_raw(socket1, "EXIT\n")
      :timer.sleep(@sleep_time)
      html = render(view)
      # assert html =~ "No clients found"
      refute html =~ "#{user1.name}"
      refute html =~ "#{user2.name}"
    end

    @tag :needs_attention
    test "show - valid client", %{conn: conn} do
      {:ok, server_context} = Teiserver.TeiserverTestLib.start_spring_server()
      %{socket: socket, user: user} = TeiserverTestLib.auth_setup(server_context)
      # client = Client.get_client_by_id(user.id)

      {:ok, view, html} = live(conn, "/teiserver/admin/client/#{user.id}")
      assert html =~ user.name
      assert html =~ "Bot: false"
      assert html =~ "Moderator: false"
      assert html =~ "Verified: true"
      # The nil is on a newline with padding so don't worry about it
      assert html =~ "Battle:"

      # Log out the user
      # FIXME: this part is failing because the liveview subscribes to old pubsubs
      _send_raw(socket, "EXIT\n")
      assert_redirect(view, "/teiserver/admin/client", 250)
    end

    @tag :needs_attention
    test "show - no client", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/teiserver/admin/client"}}} =
               live(conn, "/teiserver/admin/client/0")
    end

    test "force disconnect client", %{conn: conn} do
      {:ok, server_context} = Teiserver.TeiserverTestLib.start_spring_server()
      %{user: user} = TeiserverTestLib.auth_setup(server_context)

      {:ok, view, _html} = live(conn, "/teiserver/admin/client/#{user.id}")
      assert Client.get_client_by_id(user.id) != nil

      render_click(view, "force-reconnect", %{})
      assert_redirect(view, "/teiserver/admin/client", 250)

      assert Client.get_client_by_id(user.id) == nil
    end
  end
end
