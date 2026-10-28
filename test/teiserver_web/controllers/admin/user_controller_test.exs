defmodule TeiserverWeb.Admin.UserControllerTest do
  alias Teiserver.AccountFixtures
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.TeiserverTestLib

  use TeiserverWeb.ConnCase

  setup do
    TeiserverTestLib.server_permissions()
    |> GeneralTestLib.conn_setup()
    |> TeiserverTestLib.conn_setup()
  end

  describe "index" do
    test "lists all users", %{conn: conn} do
      _user = AccountFixtures.user_fixture()

      conn = get(conn, ~p"/teiserver/admin/user")
      assert html_response(conn, 200) =~ "Listing Users"
    end

    test "lists all users - redirect", %{conn: conn} do
      user = AccountFixtures.user_fixture()

      conn = get(conn, ~p"/teiserver/admin/user" <> "?s=#{user.name}")
      assert redirected_to(conn) == ~p"/teiserver/admin/user/#{user.id}"
    end

    test "search", %{conn: conn} do
      conn = post(conn, ~p"/teiserver/admin/users/search", search: %{})
      assert html_response(conn, 200) =~ "Listing Users"
    end
  end

  describe "show user" do
    test "renders form", %{conn: conn, user: user} do
      conn = get(conn, ~p"/teiserver/admin/user/#{user.id}")
      assert html_response(conn, 200) =~ "Smurf search"
    end
  end
end
