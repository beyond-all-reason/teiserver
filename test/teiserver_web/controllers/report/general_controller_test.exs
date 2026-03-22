defmodule TeiserverWeb.Report.GeneralControllerTest do
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.TeiserverTestLib

  use TeiserverWeb.ConnCase

  setup do
    GeneralTestLib.conn_setup(TeiserverTestLib.admin_permissions())
    |> TeiserverTestLib.conn_setup()
  end

  test "index", %{conn: conn} do
    conn = get(conn, Routes.ts_reports_general_path(conn, :index))

    assert html_response(conn, 200)
  end
end
