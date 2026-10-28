defmodule TeiserverWeb.Moderation.BannedIPLive.ListTest do
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.ModerationFixtures

  use TeiserverWeb.ConnCase, async: true

  @create_attrs %{cidr: "100.100.0.1/32"}
  @update_attrs %{cidr: "200.200.0.1/32"}
  @invalid_attrs %{cidr: nil}

  describe "access control" do
    test "cannot access list page without authenticating" do
      {:ok, kw} = GeneralTestLib.conn_setup([], [:no_login])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/moderation/banned_ips")
      assert path == ~p"/login"
    end

    test "cannot access list page when unauthorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Overwatch"])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/moderation/banned_ips")
      assert path == ~p"/"
    end

    test "can access list page when authorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Moderator"])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:ok, live, _html} = live(conn, ~p"/moderation/banned_ips")

      assert has_element?(live, "#banned_ips-table")
    end
  end

  describe "rendering data" do
    setup [:auth]

    test "no records", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/moderation/banned_ips")

      # Should have an empty table as we have no records at this time
      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      assert Enum.empty?(table.rows)
    end

    test "with records" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Moderator"])
      {:ok, conn} = Keyword.fetch(kw, :conn)

      ModerationFixtures.banned_ip_fixture(%{cidr: "192.168.0.1/32"})
      ModerationFixtures.banned_ip_fixture(%{cidr: "192.168.0.2/32"})
      ModerationFixtures.banned_ip_fixture(%{cidr: "192.168.0.3/32"})

      {:ok, live, _html} = live(conn, ~p"/moderation/banned_ips")

      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      # Should have an empty table as we have no records at this time
      assert table.headers == [
               "IP",
               "Actions"
             ]

      assert Enum.count(table.rows) == 3
    end

    test "search", %{conn: conn} do
      ModerationFixtures.banned_ip_fixture(%{cidr: "127.0.0.1/24"})

      for i <- 1..40 do
        ModerationFixtures.banned_ip_fixture(%{cidr: "192.168.0.#{i}/32"})
      end

      {:ok, live, html} = live(conn, ~p"/moderation/banned_ips")

      assert html =~ "41 banned ips found"

      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      assert Enum.count(table.rows) == 41

      # What if we update the search to show fewer results?
      live
      |> form("#banned_ip-search-form")
      |> render_submit(%{"page_size" => "25"})

      # Should now be 41
      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      assert Enum.count(table.rows) == 25

      # But then we limit what we're searching for
      live
      |> form("#banned_ip-search-form")
      |> render_submit(%{"ip" => "127."})

      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      assert Enum.count(table.rows) == 1

      # Remove that filter
      live
      |> form("#banned_ip-search-form")
      |> render_submit(%{"ip" => "", "page_size" => "5"})

      # Next page of results
      live
      |> element(".paginate-next")
      |> render_click()

      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      assert Enum.count(table.rows) == 5
    end
  end

  describe "changing data" do
    setup [:auth]

    test "saves banned_ip", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/moderation/banned_ips")

      assert index_live |> element("a", "Banned IP") |> render_click() =~
               "Banned IP"

      assert_patch(index_live, ~p"/moderation/banned_ips/new")

      assert index_live
             |> form("#banned_ip-form", banned_ip: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#banned_ip-form", banned_ip: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/moderation/banned_ips")

      html = render(index_live)
      assert html =~ "Banned ip created successfully"
      assert html =~ "100.100.0.1/32"
    end

    test "updates banned_ip in listing", %{conn: conn} do
      banned_ip = ModerationFixtures.banned_ip_fixture()
      {:ok, index_live, _html} = live(conn, ~p"/moderation/banned_ips")

      assert index_live |> element("#banned_ips-#{banned_ip.id} a", "Edit") |> render_click() =~
               "Edit Banned IP"

      assert_patch(index_live, ~p"/moderation/banned_ips/#{banned_ip}/edit")

      assert index_live
             |> form("#banned_ip-form", banned_ip: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#banned_ip-form", banned_ip: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/moderation/banned_ips")

      html = render(index_live)
      assert html =~ "Banned ip updated successfully"
      assert html =~ "200.200.0.1/32"
    end

    test "deletes banned_ip in listing", %{conn: conn} do
      banned_ip = ModerationFixtures.banned_ip_fixture()
      {:ok, index_live, _html} = live(conn, ~p"/moderation/banned_ips")

      assert index_live |> element("#banned_ips-#{banned_ip.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#banned_ips-#{banned_ip.id}")
    end
  end

  defp auth(_state) do
    TeiserverTestLib.moderator_permissions()
    |> GeneralTestLib.conn_setup()
    |> TeiserverTestLib.conn_setup()
  end
end
