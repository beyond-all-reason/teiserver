defmodule TeiserverWeb.Admin.OAuthApplicationLive.ListTest do
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.OAuth.ApplicationQueries
  alias Teiserver.OAuthFixtures
  alias Teiserver.Repo

  use TeiserverWeb.ConnCase, async: true

  @create_attrs %{
    name: "fixture app",
    uid: "fixture_app",
    scopes: ["tachyon.lobby"],
    redirect_uris: "http://localhost/foo",
    description: "app created as part of a test"
  }
  @update_attrs %{
    name: "other fixture app",
    uid: "other_fixture_app",
    scopes: ["tachyon.lobby"],
    redirect_uris: "http://localhost/foo",
    description: "other_app created as part of a test"
  }
  @invalid_attrs %{name: nil}

  describe "access control" do
    test "cannot access list page without authenticating" do
      {:ok, kw} = GeneralTestLib.conn_setup([], [:no_login])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/admin/oauth_applications")
      assert path == ~p"/login"
    end

    test "cannot access list page when unauthorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Moderator"])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/admin/oauth_applications")
      assert path == ~p"/"
    end

    test "can access list page when authorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Admin"])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:ok, live, _html} = live(conn, ~p"/admin/oauth_applications")

      assert has_element?(live, "#oauth_applications-table")
    end
  end

  describe "rendering data" do
    setup [:auth]

    test "no records", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/admin/oauth_applications")

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

      OAuthFixtures.app_fixture()
      OAuthFixtures.app_fixture()
      OAuthFixtures.app_fixture()

      {:ok, live, _html} = live(conn, ~p"/admin/oauth_applications")

      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      # Should have an empty table as we have no records at this time
      assert table.headers == [
               "ID",
               "Client ID (UID)",
               "Name",
               "Description",
               "Owner",
               "Scopes",
               "Code / Token / Creds",
               "Actions"
             ]

      assert Enum.count(table.rows) == 3
    end

    test "search", %{conn: conn} do
      OAuthFixtures.app_fixture(%{name: "My name"})

      for i <- 1..40 do
        OAuthFixtures.app_fixture(%{name: "some_other#{i}"})
      end

      {:ok, live, html} = live(conn, ~p"/admin/oauth_applications")

      assert html =~ "41 oauth applications found"

      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      assert Enum.count(table.rows) == 41

      # What if we update the search to show fewer results?
      live
      |> form("#oauth_application-search-form")
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
      |> form("#oauth_application-search-form")
      |> render_submit(%{"name" => "some_other"})

      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      assert Enum.count(table.rows) == 40

      # Remove that filter
      live
      |> form("#oauth_application-search-form")
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

    test "saves oauth_application", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/oauth_applications")

      assert index_live |> element("a", "New oauth application") |> render_click() =~
               "New oauth application"

      assert_patch(index_live, ~p"/admin/oauth_applications/new")

      assert index_live
             |> form("#oauth_application-form", application: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#oauth_application-form",
               application: Map.put(@create_attrs, :name, "new-app")
             )
             |> render_submit()

      applications =
        ApplicationQueries.applications()
        |> ApplicationQueries.where_name_like("new-app")
        |> Repo.all()

      assert Enum.count(applications) == 1
      [application] = applications

      {path, _flash} = assert_redirect(index_live)
      code_key = String.split(path, "/") |> List.last()
      assert code = Teiserver.cache_get(:secrets, code_key)

      # Ensure we have actually been forwarded to view the application
      assert path == ~p"/admin/oauth_applications/#{application.id}/show/#{code_key}"

      {:ok, _show_live, html} = live(conn, path)
      assert html =~ "Client secret, this will be shown once only!"
      assert html =~ code

      # If we look at this normally, ensure we don't get a code (which will vanish
      # in a few seconds anyway)
      {:ok, _show_live, html} = live(conn, ~p"/admin/oauth_applications/#{application.id}")
      refute html =~ "Client secret, this will be shown once only!"
      refute html =~ code
    end

    test "updates oauth_application in listing", %{conn: conn} do
      oauth_application = OAuthFixtures.app_fixture()
      {:ok, index_live, _html} = live(conn, ~p"/admin/oauth_applications")

      assert index_live
             |> element("#oauth_applications-#{oauth_application.id} a", "Edit")
             |> render_click() =~
               "Edit"

      assert_patch(index_live, ~p"/admin/oauth_applications/#{oauth_application}/edit")

      assert index_live
             |> form("#oauth_application-form", application: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#oauth_application-form", application: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/admin/oauth_applications")

      html = render(index_live)
      assert html =~ "OAuth application updated successfully"
      assert html =~ "other fixture app"
    end
  end

  defp auth(_state) do
    TeiserverTestLib.admin_permissions()
    |> GeneralTestLib.conn_setup()
    |> TeiserverTestLib.conn_setup()
  end
end
