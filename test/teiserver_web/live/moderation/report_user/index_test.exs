defmodule TeiserverWeb.Moderation.ReportUser.IndexLiveTest do
  @moduledoc false
  use TeiserverWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias Central.Helpers.GeneralTestLib
  alias Teiserver.{Moderation, TeiserverTestLib}

  defp auth_setup(_) do
    GeneralTestLib.conn_setup(TeiserverTestLib.player_permissions())
    |> TeiserverTestLib.conn_setup()
  end

  defp anon_setup(_) do
    GeneralTestLib.conn_setup([], [:no_login])
  end

  describe "Anon" do
    setup [:anon_setup]

    test "index", %{conn: conn} do
      user = TeiserverTestLib.new_user()
      {:ok, _index_live, html} = live(conn, ~p"/moderation/report_user/#{user.id}")

      assert html =~ "You must be logged in to report someone"
      assert html =~ "Reporting user: #{user.name}"
      refute html =~ "Chat / Communication"
      refute html =~ "Type of chat"
      refute html =~ "Which match?"
      refute html =~ "select-no-match"
      refute html =~ "Extra info:"
    end
  end

  describe "Index" do
    setup [:auth_setup]

    test "anon index", %{conn: conn, user: conn_user} do
      user = TeiserverTestLib.new_user()

      # Ensure no existing groups
      assert Enum.empty?(Moderation.list_report_groups(where: [target_id: user.id]))
      assert Enum.empty?(Moderation.list_reports(where: [target_id: user.id]))

      {:ok, index_live, html} = live(conn, ~p"/moderation/report_user/#{user.id}")

      assert html =~ "Reporting user: #{user.name}"
      assert html =~ "Chat / Communication"
      refute html =~ "Type of chat"
      refute html =~ "Which match?"
      refute html =~ "select-no-match"
      refute html =~ "Extra info:"

      # Select type of chat
      html = index_live |> element("#type-chat") |> render_click()
      refute html =~ "Chat / Communication"
      assert html =~ "Type of chat"
      refute html =~ "Which match?"
      refute html =~ "select-no-match"
      refute html =~ "Extra info:"

      # Select sub-type of Hate speech
      html = index_live |> element("#sub_type-hate") |> render_click()
      refute html =~ "Chat / Communication"
      refute html =~ "Type of chat"
      assert html =~ "Which match?"
      assert html =~ "select-no-match"
      refute html =~ "Extra info:"

      # Select no match
      html = index_live |> element("#select-no-match-btn") |> render_click()
      refute html =~ "Chat / Communication"
      refute html =~ "Type of chat"
      refute html =~ "Which match?"
      refute html =~ "select-no-match"
      assert html =~ "Extra info:"

      # Insert extra info

      html =
        index_live
        |> element("#report_extra_text")
        |> render_keyup(%{"value" => "The extra text in my report"})

      assert html =~ "Extra info:"
      # assert html =~ "The extra text in my report"

      html = index_live |> element("#submit-report-btn") |> render_click()
      refute html =~ "Chat / Communication"
      refute html =~ "Type of chat"
      refute html =~ "Which match?"
      refute html =~ "select-no-match"
      refute html =~ "Extra info:"
      assert html =~ "Your report has been submitted"

      # Lets see if the report has come through!
      [report_group] = Moderation.list_report_groups(where: [target_id: user.id])
      assert report_group.report_count == 1

      [report] = Moderation.list_reports(where: [target_id: user.id])
      assert report.extra_text == "The extra text in my report"
      assert report.target_id == user.id
      assert report.reporter_id == conn_user.id
    end
  end
end
