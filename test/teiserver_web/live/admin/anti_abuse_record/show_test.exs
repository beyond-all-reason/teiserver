defmodule TeiserverWeb.Admin.AntiAbuseRecordLive.ShowTest do
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.Logging.LoggingTestLib
  alias Teiserver.ModerationFixtures

  use TeiserverWeb.ConnCase, async: true

  import Teiserver.Helper.StringHelper, only: [uuid_part: 1]

  describe "access control" do
    test "cannot access show page without authenticating" do
      {:ok, kw} = GeneralTestLib.conn_setup([], [:no_login])
      {:ok, conn} = Keyword.fetch(kw, :conn)

      {:error, {:redirect, %{to: path}}} =
        live(conn, ~p"/admin/anti-abuse-records/d9aa6217-8eab-46f3-9dbf-593b8173c85c")

      assert path == ~p"/login"
    end

    test "cannot access show page when unauthorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Moderator"])
      {:ok, conn} = Keyword.fetch(kw, :conn)

      {:error, {:redirect, %{to: path}}} =
        live(conn, ~p"/admin/anti-abuse-records/d9aa6217-8eab-46f3-9dbf-593b8173c85c")

      assert path == ~p"/"
    end

    test "can access show page when authorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Senior moderator"])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      user = kw[:user]
      scope = GeneralTestLib.scope_fixture(user)
      aar = ModerationFixtures.anti_abuse_record_fixture(scope)

      {:ok, _live, _html} = live(conn, ~p"/admin/anti-abuse-records/#{aar.id}")

      audit_log = LoggingTestLib.get_most_recent_audit_log_for_user(user.id)
      assert audit_log.action == "Anti-abuse record access"
      assert audit_log.details == %{"action" => "show", "id" => aar.id}
      assert audit_log.ip == "127.0.0.1"
    end
  end

  describe "rendering data" do
    test "redirect on no record" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Senior moderator"])
      {:ok, conn} = Keyword.fetch(kw, :conn)

      {:error,
       {:redirect,
        %{
          status: 302,
          to: "/admin/anti-abuse-records/list",
          flash: _flash
        }}} =
        live(conn, ~p"/admin/anti-abuse-records/d9aa6217-8eab-46f3-9dbf-593b8173c85c")

      audit_log = LoggingTestLib.get_most_recent_audit_log_for_user(kw[:user].id)
      assert audit_log.action == "Anti-abuse record access"
      assert audit_log.details == %{"action" => "show", "id" => nil}
      assert audit_log.ip == "127.0.0.1"
    end

    test "render record" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Senior moderator"])
      {:ok, conn} = Keyword.fetch(kw, :conn)

      user = kw[:user]
      scope = GeneralTestLib.scope_fixture(user)

      aar =
        ModerationFixtures.anti_abuse_record_fixture(%{
          scope: scope,
          restored_by_id: user.id,
          restored_at: DateTime.utc_now() |> DateTime.shift(day: 1)
        })

      {:ok, _live, html} = live(conn, ~p"/admin/anti-abuse-records/#{aar.id}")

      assert html =~ ~s(Anti-abuse record: #{uuid_part(aar.id)})
      assert html =~ ~s(User record is not clean)
      refute html =~ ~s(User record is clean)
      assert html =~ ~s(Restored by: #{user.name})

      audit_log = LoggingTestLib.get_most_recent_audit_log_for_user(kw[:user].id)
      assert audit_log.action == "Anti-abuse record access"
      assert audit_log.details == %{"action" => "show", "id" => aar.id}
      assert audit_log.ip == "127.0.0.1"
    end
  end
end
