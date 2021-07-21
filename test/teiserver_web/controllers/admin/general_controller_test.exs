defmodule TeiserverWeb.Admin.GeneralControllerTest do
  use CentralWeb.ConnCase

  alias Central.Helpers.GeneralTestLib

  setup do
    GeneralTestLib.conn_setup(Teiserver.TeiserverTestLib.admin_permissions())
    |> Teiserver.TeiserverTestLib.conn_setup()
  end

  test "index", %{conn: conn} do
    conn = get(conn, Routes.ts_admin_general_path(conn, :index))

    assert html_response(conn, 200) =~ "User admin"
    assert html_response(conn, 200) =~ "Parties"
    assert html_response(conn, 200) =~ "Clan admin"
    assert html_response(conn, 200) =~ "Queues"
  end
end
