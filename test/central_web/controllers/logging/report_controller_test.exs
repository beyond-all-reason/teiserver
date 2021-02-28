defmodule CentralWeb.Logging.ReportControllerTest do
  use CentralWeb.ConnCase, async: true

  # alias Central.Helpers.DatePresets

  alias Central.Helpers.GeneralTestLib
  alias Central.Logging.LoggingTestLib

  setup do
    GeneralTestLib.conn_setup(~w(admin))
    |> LoggingTestLib.logging_setup()
  end

  test "shows report index page", %{conn: conn} do
    conn = get(conn, Routes.logging_report_path(conn, :index))
    assert html_response(conn, 200) =~ "Most recent users"
  end

  test "no report", %{conn: conn} do
    assert_raise RuntimeError, "No handler for name of 'no_report'", fn ->
      get(conn, Routes.logging_report_path(conn, :show, "no_report"))
    end
  end

  test "most_recent_users report", %{conn: conn} do
    resp = get(conn, Routes.logging_report_path(conn, :show, "most_recent_users"))
    assert html_response(resp, 200) =~ "Latest users - Server time"
  end

  # test "most_recent_users report", %{conn: conn, main_group: group} do
  #   resp = get conn, Routes.logging_report_path(conn, :show, "most_recent_users")
  #   assert html_response(resp, 200) =~ "Latest users - Server time"

  #   params = %{
  #     "path" => ["", "bedrock"],
  #     "group" => ["", "#{group.id}"],
  #     "mode" => ["User", "Group", "Path (Full)", "Path (1 part)", "Path (2 parts)", "Path (3 parts)", "Path (4 parts)"],
  #     "section" => ["", "bedrock"],

  #     "start_date" => :date,
  #     "end_date" => :date,
  #     "date_preset" => Enum.slice(DatePresets.presets(), 0, 2),
  #   }

  #   combos = GeneralTestLib.make_combos(params)

  #   for combo_data <- combos do
  #     resp = post conn, Routes.logging_report_path(conn, :show, "individual_page_views"), report: combo_data
  #     assert html_response(resp, 200)
  #   end
  # end
end
