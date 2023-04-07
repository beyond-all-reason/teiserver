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
end
