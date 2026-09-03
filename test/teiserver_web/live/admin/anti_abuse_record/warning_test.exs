defmodule TeiserverWeb.Admin.AntiAbuseRecordLive.WarningTest do
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.Logging.LoggingTestLib

  use TeiserverWeb.ConnCase, async: true

  describe "access control" do
    test "cannot access warning page without authenticating" do
      {:ok, kw} = GeneralTestLib.conn_setup([], [:no_login])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/admin/anti-abuse-records")
      assert path == ~p"/login"
    end

    test "cannot access warning page when unauthorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Moderator"])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/admin/anti-abuse-records")
      assert path == ~p"/"
    end

    test "can access warning page when authorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Senior moderator"])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:ok, live, _html} = live(conn, ~p"/admin/anti-abuse-records")

      assert has_element?(live, "#warning-text")
      html = element(live, "#warning-text") |> render()

      assert html =~ "All access beyond this point is logged and reviewed."

      audit_log = LoggingTestLib.get_most_recent_audit_log_for_user(kw[:user].id)
      assert audit_log == nil
    end
  end
end
