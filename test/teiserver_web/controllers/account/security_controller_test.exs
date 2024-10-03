defmodule TeiserverWeb.Account.SecurityControllerTest do
  use TeiserverWeb.ConnCase

  alias Central.Helpers.GeneralTestLib

  test "redirected to edit password once logged in" do
    {:ok, kw} = GeneralTestLib.conn_setup([], [:no_login])
    {:ok, conn} = Keyword.fetch(kw, :conn)
    {:ok, user} = Keyword.fetch(kw, :user)

    conn = get(conn, ~p"/teiserver/account/security/edit_password")
    assert redirected_to(conn) == ~p"/login"
    conn = GeneralTestLib.login(conn, user.email)
    assert redirected_to(conn) == ~p"/teiserver/account/security/edit_password"
  end
end
