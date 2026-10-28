defmodule TeiserverWeb.Moderation.BannedDomainLive.ListTest do
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.ModerationFixtures

  use TeiserverWeb.ConnCase, async: true

  @create_attrs %{domain: "some domain"}
  @update_attrs %{domain: "some other domain"}
  @invalid_attrs %{domain: nil}

  describe "access control" do
    test "cannot access list page without authenticating" do
      {:ok, kw} = GeneralTestLib.conn_setup([], [:no_login])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/moderation/banned_domains")
      assert path == ~p"/login"
    end

    test "cannot access list page when unauthorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Overwatch"])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/moderation/banned_domains")
      assert path == ~p"/"
    end

    test "can access list page when authorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Moderator"])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:ok, live, _html} = live(conn, ~p"/moderation/banned_domains")

      assert has_element?(live, "#banned_domains-table")
    end
  end

  describe "rendering data" do
    setup [:auth]

    test "no records", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/moderation/banned_domains")

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

      ModerationFixtures.banned_domain_fixture()
      ModerationFixtures.banned_domain_fixture()
      ModerationFixtures.banned_domain_fixture()

      {:ok, live, _html} = live(conn, ~p"/moderation/banned_domains")

      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      # Should have an empty table as we have no records at this time
      assert table.headers == [
               "Domain",
               "Actions"
             ]

      assert Enum.count(table.rows) == 3
    end

    test "search", %{conn: conn} do
      ModerationFixtures.banned_domain_fixture(%{domain: "My domain"})

      for i <- 1..40 do
        ModerationFixtures.banned_domain_fixture(%{domain: "some_other#{i}"})
      end

      {:ok, live, html} = live(conn, ~p"/moderation/banned_domains")

      assert html =~ "41 Banned Domains found"

      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      assert Enum.count(table.rows) == 41

      # What if we update the search to show fewer results?
      live
      |> form("#banned_domain-search-form")
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
      |> form("#banned_domain-search-form")
      |> render_submit(%{"domain" => "some_other"})

      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      assert Enum.count(table.rows) == 40

      # Remove that filter
      live
      |> form("#banned_domain-search-form")
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

    test "saves banned_domain", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/moderation/banned_domains")

      assert index_live |> element("a", "Banned Domain") |> render_click() =~
               "Banned Domain"

      assert_patch(index_live, ~p"/moderation/banned_domains/new")

      assert index_live
             |> form("#banned_domain-form", banned_domain: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#banned_domain-form", banned_domain: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/moderation/banned_domains")

      html = render(index_live)
      assert html =~ "Banned domain created successfully"
      assert html =~ "some domain"
    end

    test "updates banned_domain in listing", %{conn: conn} do
      banned_domain = ModerationFixtures.banned_domain_fixture()
      {:ok, index_live, _html} = live(conn, ~p"/moderation/banned_domains")

      assert index_live
             |> element("#banned_domains-#{banned_domain.id} a", "Edit")
             |> render_click() =~
               "Edit Banned Domain"

      assert_patch(index_live, ~p"/moderation/banned_domains/#{banned_domain}/edit")

      assert index_live
             |> form("#banned_domain-form", banned_domain: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#banned_domain-form", banned_domain: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/moderation/banned_domains")

      html = render(index_live)
      assert html =~ "Banned domain updated successfully"
      assert html =~ "some other domain"
    end

    test "deletes banned_domain in listing", %{conn: conn} do
      banned_domain = ModerationFixtures.banned_domain_fixture()
      {:ok, index_live, _html} = live(conn, ~p"/moderation/banned_domains")

      assert index_live
             |> element("#banned_domains-#{banned_domain.id} a", "Delete")
             |> render_click()

      refute has_element?(index_live, "#banned_domains-#{banned_domain.id}")
    end
  end

  defp auth(_state) do
    TeiserverTestLib.moderator_permissions()
    |> GeneralTestLib.conn_setup()
    |> TeiserverTestLib.conn_setup()
  end
end
