defmodule BarserverWeb.Account.GeneralControllerTest do
  use BarserverWeb.ConnCase

  alias Central.Helpers.GeneralTestLib

  setup do
    GeneralTestLib.conn_setup(Barserver.BarserverTestLib.player_permissions())
    |> Barserver.BarserverTestLib.conn_setup()
  end

  test "index", %{conn: conn} do
    conn = get(conn, Routes.ts_account_general_path(conn, :index))

    assert html_response(conn, 200) =~ "Friends/Mutes/Invites"
    assert html_response(conn, 200) =~ "Preferences"
  end

  test "relationships", %{conn: conn} do
    conn = get(conn, Routes.ts_account_relationships_path(conn, :index))

    assert html_response(conn, 200) =~ "Pending requests"
    assert html_response(conn, 200) =~ "Clan invites"
  end

  test "admin permissions", %{conn: conn} do
    assert_raise Bodyguard.NotAuthorizedError, fn ->
      get(conn, Routes.ts_admin_general_path(conn, :index))
    end
  end
end
