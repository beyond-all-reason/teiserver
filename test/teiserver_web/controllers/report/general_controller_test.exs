defmodule TeiserverWeb.Report.GeneralControllerTest do
  use TeiserverWeb.ConnCase

  alias Central.Helpers.GeneralTestLib
  alias Teiserver.TeiserverTestLib

  setup do
    GeneralTestLib.conn_setup(TeiserverTestLib.admin_permissions())
    |> TeiserverTestLib.conn_setup()
  end

  @tag :needs_attention
  test "index", %{conn: conn} do
    conn = get(conn, Routes.ts_reports_general_path(conn, :index))

    assert html_response(conn, 200)
  end
end
