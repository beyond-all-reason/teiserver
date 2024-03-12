defmodule BarserverWeb.Report.GeneralControllerTest do
  use BarserverWeb.ConnCase

  alias Central.Helpers.GeneralTestLib

  setup do
    GeneralTestLib.conn_setup(Barserver.BarserverTestLib.admin_permissions())
    |> Barserver.BarserverTestLib.conn_setup()
  end

  test "index", %{conn: conn} do
    conn = get(conn, Routes.ts_reports_general_path(conn, :index))

    assert html_response(conn, 200)
  end
end
