defmodule TeiserverWeb.Report.ServerMetricControllerTest do
  use CentralWeb.ConnCase

  alias Central.Helpers.GeneralTestLib

  setup do
    GeneralTestLib.conn_setup(Teiserver.TeiserverTestLib.admin_permissions())
    |> Teiserver.TeiserverTestLib.conn_setup()
  end

  test "index", %{conn: conn} do
    conn = get(conn, Routes.ts_reports_server_metric_path(conn, :day_metrics_list))

    assert html_response(conn, 200)
  end
end
