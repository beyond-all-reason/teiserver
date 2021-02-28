defmodule CentralWeb.Admin.GeneralControllerTest do
  use CentralWeb.ConnCase, async: true

  alias Central.Helpers.GeneralTestLib

  setup do
    GeneralTestLib.conn_setup(~w(admin))
  end

  test "show admin index", %{conn: conn} do
    conn = get(conn, Routes.admin_general_path(conn, :index))
    assert html_response(conn, 200) =~ "Last build: "
  end
end
