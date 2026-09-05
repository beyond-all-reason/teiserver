defmodule TeiserverWeb.Admin.AntiAbuseRecordLive.ListTest do
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.Logging.LoggingTestLib
  alias Teiserver.ModerationFixtures

  use TeiserverWeb.ConnCase, async: true

  import Teiserver.Helper.StringHelper, only: [uuid_part: 1]

  describe "access control" do
    test "cannot access list page without authenticating" do
      {:ok, kw} = GeneralTestLib.conn_setup([], [:no_login])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/admin/anti-abuse-records/list")
      assert path == ~p"/login"
    end

    test "cannot access list page when unauthorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Moderator"])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/admin/anti-abuse-records/list")
      assert path == ~p"/"
    end

    test "can access list page when authorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Senior moderator"])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:ok, live, _html} = live(conn, ~p"/admin/anti-abuse-records/list")

      assert has_element?(live, "#anti-abuse-records-table")

      audit_log = LoggingTestLib.get_most_recent_audit_log_for_user(kw[:user].id)
      assert audit_log.action == "Anti-abuse record access"
      assert audit_log.details == %{"action" => "list", "id" => nil}
      assert audit_log.ip == "127.0.0.1"
    end
  end

  describe "rendering data" do
    test "no records" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Senior moderator"])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:ok, live, _html} = live(conn, ~p"/admin/anti-abuse-records/list")

      # Should have an empty table as we have no records at this time
      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      assert Enum.empty?(table.rows)

      audit_log = LoggingTestLib.get_most_recent_audit_log_for_user(kw[:user].id)
      assert audit_log.action == "Anti-abuse record access"
      assert audit_log.details == %{"action" => "list", "id" => nil}
      assert audit_log.ip == "127.0.0.1"
    end

    test "with records" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Senior moderator"])
      {:ok, conn} = Keyword.fetch(kw, :conn)

      user = kw[:user]
      scope = GeneralTestLib.scope_fixture(user)

      # Blank AAR
      aar1 = ModerationFixtures.anti_abuse_record_fixture(scope)

      # AAR with fields
      aar2 =
        ModerationFixtures.anti_abuse_record_fixture(%{
          scope: scope,
          expires_at: DateTime.utc_now()
        })

      # Restored AAR
      aar3 =
        ModerationFixtures.anti_abuse_record_fixture(%{
          scope: scope,
          restored_by_id: user.id,
          restored_at: DateTime.utc_now() |> DateTime.shift(day: 1)
        })

      {:ok, live, _html} = live(conn, ~p"/admin/anti-abuse-records/list")

      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      # Should have an empty table as we have no records at this time
      assert table.headers == [
               "ID",
               "User ID",
               "Created",
               "Clean ?",
               "Expires",
               "Restored",
               "Restored by",
               "Actions"
             ]

      assert Enum.count(table.rows) == 3

      row1 = extract_row(table, "ID", uuid_part(aar1.id))
      assert row1["Restored by"] == ""

      row2 = extract_row(table, "ID", uuid_part(aar2.id))
      assert row2["Restored by"] == ""

      row3 = extract_row(table, "ID", uuid_part(aar3.id))
      assert row3["Restored by"] == user.name

      audit_log = LoggingTestLib.get_most_recent_audit_log_for_user(user.id)
      assert audit_log.action == "Anti-abuse record access"
      assert audit_log.details == %{"action" => "list", "id" => nil}
      assert audit_log.ip == "127.0.0.1"
    end

    test "search" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Senior moderator"])
      {:ok, conn} = Keyword.fetch(kw, :conn)

      user = kw[:user]
      scope = GeneralTestLib.scope_fixture(user)

      for _i <- 1..20 do
        ModerationFixtures.anti_abuse_record_fixture(scope)
      end

      for _i <- 1..20 do
        ModerationFixtures.anti_abuse_record_fixture(%{
          scope: scope,
          clean: true,
          expires_at: DateTime.utc_now()
        })
      end

      ModerationFixtures.anti_abuse_record_fixture(%{
        scope: scope,
        restored_by_id: user.id,
        restored_at: DateTime.utc_now() |> DateTime.shift(day: 1)
      })

      {:ok, live, html} = live(conn, ~p"/admin/anti-abuse-records/list")

      # 20 + 20 + 1 = 41 records
      assert html =~ "41 records found"

      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      # By default we show 25 (set by the user config)
      assert Enum.count(table.rows) == 25

      # What if we update the search to show more results?
      live
      |> form("#anti-abuse-record-search-form")
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
      |> form("#anti-abuse-record-search-form")
      |> render_submit(%{"clean?" => "true"})

      {:ok, table} =
        live
        |> element("table")
        |> render()
        |> table_to_map()

      # Only 20 clean results
      assert Enum.count(table.rows) == 20

      # Remove that filter
      live
      |> form("#anti-abuse-record-search-form")
      |> render_submit(%{"clean?" => "", "page_size" => "25"})

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
      assert Enum.count(table.rows) == 16
    end
  end
end
