defmodule TeiserverWeb.Admin.DiscordChannelLive.ListTest do
  alias Teiserver.CommunicationFixtures
  alias Teiserver.Helpers.GeneralTestLib

  use TeiserverWeb.ConnCase, async: true

  @create_attrs %{name: "some name", channel_id: 123}
  @update_attrs %{
    name: "some other name",
    channel_id: 456
  }
  @invalid_attrs %{name: nil, channel_id: nil}

  describe "access control" do
    test "cannot access list page without authenticating" do
      {:ok, kw} = GeneralTestLib.conn_setup([], [:no_login])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/admin/discord_channels")
      assert path == ~p"/login"
    end

    test "cannot access list page when unauthorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Moderator"])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/admin/discord_channels")
      assert path == ~p"/"
    end

    test "can access list page when authorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Admin"])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:ok, live, _html} = live(conn, ~p"/admin/discord_channels")

      assert has_element?(live, "#discord_channels-table")
    end
  end

  describe "rendering data" do
    setup [:auth]

    test "no records", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/admin/discord_channels")

      # Should have an empty table as we have no records at this time
      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      assert Enum.empty?(table.rows)
    end

    test "with records" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Admin"])
      {:ok, conn} = Keyword.fetch(kw, :conn)

      CommunicationFixtures.discord_channel_fixture()
      CommunicationFixtures.discord_channel_fixture()
      CommunicationFixtures.discord_channel_fixture()

      {:ok, live, _html} = live(conn, ~p"/admin/discord_channels")

      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      # Should have an empty table as we have no records at this time
      assert table.headers == ["Name", "Channel ID", "Actions"]

      assert Enum.count(table.rows) == 3
    end

    test "search", %{conn: conn} do
      CommunicationFixtures.discord_channel_fixture(%{name: "My name"})

      for i <- 1..40 do
        CommunicationFixtures.discord_channel_fixture(%{name: "some_other#{i}"})
      end

      {:ok, live, html} = live(conn, ~p"/admin/discord_channels")

      assert html =~ "41 discord channels found"

      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      assert Enum.count(table.rows) == 41

      # What if we update the search to show fewer results?
      live
      |> form("#discord_channel-search-form")
      |> render_submit(%{"page_size" => "50"})

      # Should now be 41
      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      # By default we show 25 (set by the user config)
      assert Enum.count(table.rows) == 41

      # But then we limit what we're searching for
      live
      |> form("#discord_channel-search-form")
      |> render_submit(%{"name" => "some_other"})

      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      assert Enum.count(table.rows) == 40

      # Remove that filter
      live
      |> form("#discord_channel-search-form")
      |> render_submit(%{"clean?" => "", "page_size" => "5"})

      # Next page of results
      live
      |> element(".paginate-next")
      |> render_click()

      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      # Only 20 clean results
      assert Enum.count(table.rows) == 5
    end
  end

  describe "changing data" do
    setup [:auth]

    test "saves discord_channel", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/discord_channels")

      assert index_live |> element("a", "New discord channel") |> render_click() =~
               "New Discord channel"

      assert_patch(index_live, ~p"/admin/discord_channels/new")

      assert index_live
             |> form("#discord_channel-form", discord_channel: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#discord_channel-form", discord_channel: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/admin/discord_channels")

      html = render(index_live)
      assert html =~ "Discord channel created successfully"
      assert html =~ "some name"
    end

    test "updates discord_channel in listing", %{conn: conn} do
      discord_channel = CommunicationFixtures.discord_channel_fixture()
      {:ok, index_live, _html} = live(conn, ~p"/admin/discord_channels")

      assert index_live
             |> element("#discord_channels-#{discord_channel.id} a", "Edit")
             |> render_click() =~
               "Edit Discord channel"

      assert_patch(index_live, ~p"/admin/discord_channels/#{discord_channel}/edit")

      assert index_live
             |> form("#discord_channel-form", discord_channel: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#discord_channel-form", discord_channel: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/admin/discord_channels")

      html = render(index_live)
      assert html =~ "Discord channel updated successfully"
      assert html =~ "some other name"
    end
  end

  defp auth(_state) do
    TeiserverTestLib.admin_permissions()
    |> GeneralTestLib.conn_setup()
    |> TeiserverTestLib.conn_setup()
  end
end
