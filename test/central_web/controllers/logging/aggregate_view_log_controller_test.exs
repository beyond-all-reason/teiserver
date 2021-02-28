# defmodule CentralWeb.Logging.AggregateViewLogControllerTest do
#   use CentralWeb.ConnCase, async: true

#   alias CentaurWeb.General.TimexHelpers

#   alias Central.Helpers.GeneralTestLib
#   alias Central.Logging.LoggingTestLib
#   setup do
#     GeneralTestLib.conn_setup()
#     |> LoggingTestLib.logging_setup(aggregate_logs: true)
#   end

#   test "lists all entries on index", %{conn: conn} do
#     conn = get conn, Routes.logging_aggregate_view_log_path(conn, :index)
#     assert html_response(conn, 200) =~ "Aggregate view logs - Row count: 11"
#   end

#   test "show log", %{conn: conn, aggregate_logs: [aggregate_log | _]} do
#     date = aggregate_log.date
#     |> TimexHelpers.ymd

#     conn = get conn, Routes.logging_aggregate_view_log_path(conn, :show, date)
#     assert html_response(conn, 200) =~ "Aggregate log view: #{Timex.format!(aggregate_log.date, "{0D}/{0M}/{YYYY}, {WDfull}")}"
#   end

#   test "conversion form", %{conn: conn} do
#     conn = get conn, Routes.logging_aggregate_view_log_path(conn, :perform_form)
#     assert html_response(conn, 200) =~ "Keep going"
#   end

#   test "conversion post", %{conn: conn} do
#     date = Timex.now()
#     |> TimexHelpers.dmy

#     conn = post conn, Routes.logging_aggregate_view_log_path(conn, :perform_post), date: date
#     assert html_response(conn, 200) =~ "Success - "
#   end
# end
