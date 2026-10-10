defmodule TeiserverWeb.Moderation.LobbyLogLive.ListTest do
  alias Teiserver.AccountFixtures
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.ModerationFixtures

  use TeiserverWeb.ConnCase, async: true

  describe "access control" do
    test "cannot access list page without authenticating" do
      {:ok, kw} = GeneralTestLib.conn_setup([], [:no_login])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/moderation/lobby_logs")
      assert path == ~p"/login"
    end

    test "cannot access list page when unauthorized" do
      {:ok, kw} = GeneralTestLib.conn_setup([])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/moderation/lobby_logs")
      assert path == ~p"/"
    end

    test "can access list page when authorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Moderator"])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:ok, live, _html} = live(conn, ~p"/moderation/lobby_logs")
      assert has_element?(live, "#lobby-logs-table")
    end
  end

  describe "rendering data" do
    setup [:auth]

    test "no records", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/moderation/lobby_logs")

      # Should have an empty table as we have no records at this time
      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      assert Enum.empty?(table.rows)
    end

    test "with records", %{conn: conn} do
      user = AccountFixtures.user_fixture()

      join = ModerationFixtures.lobby_log_fixture(%{user_id: user.id})

      leave =
        ModerationFixtures.lobby_log_fixture(%{
          event_type: :leave_lobby,
          user_id: user.id,
          details: %{"reason" => "test"}
        })

      {:ok, live, _html} = live(conn, ~p"/moderation/lobby_logs")

      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      assert table.headers == ["Lobby", "Event", "User", "Target", "Details", "Time"]
      assert Enum.count(table.rows) == 2
    end

    test "search", %{conn: conn} do
      boss = AccountFixtures.user_fixture()
      ModerationFixtures.lobby_log_fixture(%{event_type: :leave_lobby})

      for _i <- 1..20 do
        ModerationFixtures.lobby_log_fixture(%{event_type: :appoint_boss, target_id: boss.id})
        ModerationFixtures.lobby_log_fixture(%{event_type: :unboss, target_id: boss.id})
      end

      {:ok, live, html} = live(conn, ~p"/moderation/lobby_logs")

      assert html =~ "41 records found"

      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      # By default we show 50 (set by the user config)
      assert Enum.count(table.rows) == 41

      # What if we update the search to show fewer results?
      live
      |> form("#lobby-log-search-form")
      |> render_submit(%{"page_size" => "25"})

      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      assert Enum.count(table.rows) == 25

      # But then we limit what we're searching for
      live
      |> form("#lobby-log-search-form")
      |> render_submit(%{"event_type" => "leave_lobby"})

      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      assert Enum.count(table.rows) == 1

      # Remove that filter and search by target instead
      live
      |> form("#lobby-log-search-form")
      |> render_submit(%{"event_type" => "Any", "target_id" => boss.id, "page_size" => "25"})

      # 40 results, so 25 on the first page
      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      assert Enum.count(table.rows) == 25

      # Next page of results
      live
      |> element(".paginate-next")
      |> render_click()

      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      assert Enum.count(table.rows) == 15
    end
  end

  defp auth(_state) do
    TeiserverTestLib.moderator_permissions()
    |> GeneralTestLib.conn_setup()
    |> TeiserverTestLib.conn_setup()
  end
end
