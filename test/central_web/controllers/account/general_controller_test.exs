defmodule CentralWeb.Account.GeneralControllerTest do
  use CentralWeb.ConnCase

  alias Central.Helpers.GeneralTestLib

  setup do
    GeneralTestLib.conn_setup([])
  end

  test "index", %{conn: conn} do
    conn = get(conn, Routes.account_general_path(conn, :index))
    assert html_response(conn, 200) =~ "Groups"
    assert html_response(conn, 200) =~ "Preferences"
    assert html_response(conn, 200) =~ "Account details"
    assert html_response(conn, 200) =~ "Password"
  end
end
