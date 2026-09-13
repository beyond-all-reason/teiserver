defmodule TeiserverWeb.Moderation.UserLive.ListTest do
  alias Teiserver.AccountFixtures
  alias Teiserver.Helpers.GeneralTestLib

  use TeiserverWeb.ConnCase, async: true

  describe "access control" do
    test "cannot access list page without authenticating" do
      {:ok, kw} = GeneralTestLib.conn_setup([], [:no_login])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/moderation/users")
      assert path == ~p"/login"
    end

    test "cannot access list page when unauthorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Overwatch"])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/moderation/users")
      assert path == ~p"/"
    end

    test "can access list page when authorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Moderator"])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:ok, live, _html} = live(conn, ~p"/moderation/users")

      assert has_element?(live, "#users-table")
    end
  end

  describe "rendering data" do
    setup [:auth]

    # We have no "no records" test for this page as there will always
    # be at least one user, the one viewing it.

    test "with records" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Moderator"])
      {:ok, conn} = Keyword.fetch(kw, :conn)

      AccountFixtures.user_fixture(%{cidr: "192.168.0.1/32"})
      AccountFixtures.user_fixture(%{cidr: "192.168.0.2/32"})
      AccountFixtures.user_fixture(%{cidr: "192.168.0.3/32"})

      {:ok, live, _html} = live(conn, ~p"/moderation/users")

      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      # Should have an empty table as we have no records at this time
      assert table.headers == [
               "User",
               "Email",
               "Client",
               "Status",
               "HW",
               "IP",
               "Roles",
               "Registered"
             ]

      # There will always be at leas 5 users at this stage but it's possible
      # there are more
      assert Enum.count(table.rows) >= 5
    end

    test "search", %{conn: conn} do
      AccountFixtures.user_fixture(%{name: "FormidablePerson"})

      for i <- 1..40 do
        AccountFixtures.user_fixture(%{name: "CoherentPerson#{i}"})
      end

      {:ok, live, _html} = live(conn, ~p"/moderation/users")

      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      assert Enum.count(table.rows) >= 41

      # What if we update the search to show fewer results?
      live
      |> form("#user-search-form")
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
      |> form("#user-search-form")
      |> render_submit(%{"name" => "Formidable"})

      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      assert Enum.count(table.rows) == 1

      # Remove that filter
      live
      |> form("#user-search-form")
      |> render_submit(%{"name" => "", "page_size" => "5"})

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

  defp auth(_state) do
    TeiserverTestLib.moderator_permissions()
    |> GeneralTestLib.conn_setup()
    |> TeiserverTestLib.conn_setup()
  end
end
