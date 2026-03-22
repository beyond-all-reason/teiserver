defmodule TeiserverWeb.Admin.ToolControllerTest do
  alias Teiserver.Helpers.GeneralTestLib

  use TeiserverWeb.ConnCase

  setup do
    GeneralTestLib.conn_setup(~w(admin.dev.developer))
  end

  test "index", %{conn: conn} do
    conn = get(conn, Routes.ts_admin_tool_path(conn, :index))
    assert html_response(conn, 200) =~ "Test page"
  end
end
