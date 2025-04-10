defmodule TeiserverWeb.Account.GeneralControllerTest do
  use TeiserverWeb.ConnCase

  alias Central.Helpers.GeneralTestLib

  setup do
    GeneralTestLib.conn_setup(Teiserver.TeiserverTestLib.player_permissions())
    |> Teiserver.TeiserverTestLib.conn_setup()
  end

  @tag :needs_attention
  test "index", %{conn: conn} do
    conn = get(conn, Routes.ts_account_general_path(conn, :index))

    assert html_response(conn, 200) =~ "Friends/Mutes/Invites"
    assert html_response(conn, 200) =~ "Preferences"
  end

  test "admin permissions", %{conn: conn} do
    assert_raise Bodyguard.NotAuthorizedError, fn ->
      get(conn, Routes.ts_admin_general_path(conn, :index))
    end
  end
end
