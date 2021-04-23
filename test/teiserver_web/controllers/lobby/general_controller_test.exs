defmodule TeiserverWeb.Lobby.GeneralControllerTest do
  use CentralWeb.ConnCase

  alias Central.Helpers.GeneralTestLib

  setup do
    GeneralTestLib.conn_setup(Teiserver.TestLib.player_permissions())
    |> Teiserver.TestLib.conn_setup()
  end

  test "index", %{conn: conn} do
    conn = get(conn, Routes.ts_lobby_general_path(conn, :index))

    assert html_response(conn, 200) =~ "Battles"
    assert html_response(conn, 200) =~ "Account"
  end
end
