defmodule TeiserverWeb.Account.GeneralControllerTest do
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.TeiserverTestLib

  use TeiserverWeb.ConnCase

  setup do
    GeneralTestLib.conn_setup(TeiserverTestLib.player_permissions())
    |> TeiserverTestLib.conn_setup()
  end

  test "index", %{conn: conn} do
    conn = get(conn, ~p"/teiserver/account/details")
    assert html_response(conn, 200) =~ "Edit account details"
  end

  test "admin permissions", %{conn: conn} do
    resp = get(conn, ~p"/teiserver/admin")
    assert redirected_to(resp) == ~p"/"
  end
end
