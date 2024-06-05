defmodule TeiserverWeb.Admin.GeneralControllerTest do
  use TeiserverWeb.ConnCase

  alias Central.Helpers.GeneralTestLib

  setup do
    GeneralTestLib.conn_setup(Teiserver.TeiserverTestLib.admin_permissions())
    |> Teiserver.TeiserverTestLib.conn_setup()
  end

  @tag :needs_attention
  test "index", %{conn: conn} do
    conn = get(conn, Routes.ts_admin_general_path(conn, :index))

    assert html_response(conn, 200) =~ "Users"
  end
end
