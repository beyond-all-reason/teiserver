defmodule TeiserverWeb.Admin.ToolControllerTest do
  alias Teiserver.Helpers.GeneralTestLib

  use TeiserverWeb.ConnCase

  setup do
    GeneralTestLib.conn_setup(~w(Server))
  end

  test "index", %{conn: conn} do
    conn = get(conn, ~p"/teiserver/admin/tools")
    assert html_response(conn, 200) =~ "Test page"
  end
end
