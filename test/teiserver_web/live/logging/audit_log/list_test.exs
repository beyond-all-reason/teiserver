defmodule TeiserverWeb.Logging.AuditLogLive.ListTest do
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.LoggingFixtures

  use TeiserverWeb.ConnCase, async: true

  describe "access control" do
    test "cannot access list page without authenticating" do
      {:ok, kw} = GeneralTestLib.conn_setup([], [:no_login])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/logging/audit_logs")
      assert path == ~p"/login"
    end

    test "cannot access list page when unauthorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Overwatch"])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/logging/audit_logs")
      assert path == ~p"/"
    end

    test "can access list page when authorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Admin"])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:ok, live, _html} = live(conn, ~p"/logging/audit_logs")

      assert has_element?(live, "#audit_logs-table")
    end
  end

  describe "rendering data" do
    setup [:auth]

    test "no records", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/logging/audit_logs")

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

      LoggingFixtures.audit_log_fixture()
      LoggingFixtures.audit_log_fixture()
      LoggingFixtures.audit_log_fixture()

      {:ok, live, _html} = live(conn, ~p"/logging/audit_logs")

      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      # Should have an empty table as we have no records at this time
      assert table.headers == [
               "ID",
               "Timestamp",
               "Action",
               "User"
             ]

      assert Enum.count(table.rows) == 3
    end

    test "search", %{conn: conn} do
      LoggingFixtures.audit_log_fixture(%{action: "my favourite action"})

      for _i <- 1..40 do
        LoggingFixtures.audit_log_fixture(%{action: "my other favourite action"})
      end

      {:ok, live, html} = live(conn, ~p"/logging/audit_logs")

      assert html =~ "41 Audit Logs found"

      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      # By default we show 50 (set by the user config)
      assert Enum.count(table.rows) == 41

      # What if we update the search to show fewer results?
      live
      |> form("#audit_log-search-form")
      |> render_submit(%{"page_size" => "25"})

      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      assert Enum.count(table.rows) == 25

      # But then we limit what we're searching for
      live
      |> form("#audit_log-search-form")
      |> render_submit(%{"action" => "my favourite action"})

      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      assert Enum.count(table.rows) == 1

      # Remove that filter
      live
      |> form("#audit_log-search-form")
      |> render_submit(%{"action" => "", "page_size" => "5"})

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
    TeiserverTestLib.admin_permissions()
    |> GeneralTestLib.conn_setup()
    |> TeiserverTestLib.conn_setup()
  end
end
