defmodule TeiserverWeb.Admin.ToolControllerTest do
  use CentralWeb.ConnCase

  alias Central.Helpers.GeneralTestLib

  setup do
    GeneralTestLib.conn_setup(~w(admin.dev.developer))
  end

  test "index", %{conn: conn} do
    conn = get(conn, Routes.ts_admin_tool_path(conn, :index))
    assert html_response(conn, 200) =~ "Badge types"
  end

  test "uberserver converter form", %{conn: conn} do
    conn = get(conn, Routes.ts_admin_tool_path(conn, :convert_form))
    assert html_response(conn, 200) =~ "Uberserver converter"
  end

  # test "uberserver converter post", %{conn: conn} do
  #   conn = post(conn, Routes.ts_admin_tool_path(conn, :convert_post))

  #   assert html_response(conn, 200) =~ "Uberserver converter"
  # end
end
