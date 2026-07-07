defmodule TeiserverWeb.Moderation.ReportControllerTest do
  @moduledoc false

  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.Moderation.ModerationTestLib
  alias Teiserver.TeiserverTestLib

  use TeiserverWeb.ConnCase

  setup do
    GeneralTestLib.conn_setup(["Reviewer", "Moderator", "Overwatch"])
    |> TeiserverTestLib.conn_setup()
  end

  describe "index" do
    test "lists all reports", %{conn: conn} do
      conn = get(conn, ~p"/moderation/report")
      assert html_response(conn, 200) =~ "Listing Reports"

      # Now with at least one report present
      ModerationTestLib.report_fixture()
      conn = get(conn, ~p"/moderation/report")
      assert html_response(conn, 200) =~ "Listing Reports"
    end

    test "show reports by target", %{conn: conn} do
      report = ModerationTestLib.report_fixture()

      conn =
        get(conn, ~p"/moderation/report?target_id=#{report.target_id}")

      assert html_response(conn, 200) =~ "Listing Reports"
    end

    test "show reports by reporter", %{conn: conn} do
      report = ModerationTestLib.report_fixture()

      conn =
        get(
          conn,
          ~p"/moderation/report?reporter_id=#{report.reporter_id}"
        )

      assert html_response(conn, 200) =~ "Listing Reports"
    end
  end

  describe "show report" do
    test "renders show page", %{conn: conn} do
      report = ModerationTestLib.report_fixture()
      resp = get(conn, ~p"/moderation/report/#{report}")
      assert html_response(resp, 200) =~ "Filter by target"
    end

    test "renders show nil item", %{conn: conn} do
      assert_error_sent 404, fn ->
        get(conn, ~p"/moderation/report/-1")
      end
    end
  end

  describe "show user" do
    test "renders user page - target", %{conn: conn} do
      new_user = GeneralTestLib.make_user()
      report = ModerationTestLib.report_fixture(%{target_id: new_user.id})
      resp = get(conn, ~p"/moderation/report/user/#{report.target_id}")
      assert html_response(resp, 200) =~ "Reports against ("
      assert html_response(resp, 200) =~ "Reports made ("
      assert html_response(resp, 200) =~ "Actions ("
    end

    test "renders user page - reporter", %{conn: conn} do
      new_user = GeneralTestLib.make_user()
      report = ModerationTestLib.report_fixture(%{reporter_id: new_user.id})
      resp = get(conn, ~p"/moderation/report/user/#{report.reporter_id}")
      assert html_response(resp, 200) =~ "Reports against ("
      assert html_response(resp, 200) =~ "Reports made ("
      assert html_response(resp, 200) =~ "Actions ("
    end
  end

  describe "delete report" do
    test "deletes chosen report", %{conn: conn} do
      report = ModerationTestLib.report_fixture()
      conn = delete(conn, ~p"/moderation/report/#{report.id}")
      assert redirected_to(conn) == ~p"/moderation/report"

      assert_error_sent 404, fn ->
        get(conn, ~p"/moderation/report/#{report}")
      end
    end

    test "renders error for deleting nil item", %{conn: conn} do
      assert_error_sent 404, fn ->
        delete(conn, ~p"/moderation/report/-1")
      end
    end
  end
end
