defmodule TeiserverWeb.Account.ViewAsControllerTest do
  alias Teiserver.AccountFixtures
  alias Teiserver.Account.ViewAs
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.TeiserverTestLib

  use TeiserverWeb.ConnCase

  describe "as an admin" do
    setup do
      GeneralTestLib.conn_setup(["Admin"])
      |> TeiserverTestLib.conn_setup()
    end

    test "can start and stop viewing as a regular user", %{conn: conn} do
      target = AccountFixtures.user_fixture(%{roles: ["Moderator"]})

      resp = post(conn, ~p"/view_as/#{target.id}")
      assert redirected_to(resp) == ~p"/"
      assert get_session(resp, ViewAs.session_key()) == target.id

      resp = delete(recycle(resp), ~p"/view_as")
      assert redirected_to(resp) == ~p"/"
      refute get_session(resp, ViewAs.session_key())
    end

    test "the swapped user is used for authorisation", %{conn: conn} do
      target = AccountFixtures.user_fixture(%{roles: []})

      conn = post(conn, ~p"/view_as/#{target.id}") |> recycle()
      # /admin requires permissions the target does not have
      resp = get(conn, ~p"/admin")
      assert redirected_to(resp) == ~p"/"
    end

    test "cannot view as another admin", %{conn: conn} do
      target = AccountFixtures.user_fixture(%{roles: ["Admin"]})

      resp = post(conn, ~p"/view_as/#{target.id}")
      assert redirected_to(resp) == ~p"/"
      refute get_session(resp, ViewAs.session_key())
    end

    test "cannot view as a nonexistent or invalid user", %{conn: conn} do
      resp = post(conn, ~p"/view_as/999999999")
      refute get_session(resp, ViewAs.session_key())

      resp = post(conn, ~p"/view_as/abc")
      refute get_session(resp, ViewAs.session_key())
    end
  end

  describe "as a non-admin" do
    setup do
      GeneralTestLib.conn_setup(["Moderator"])
      |> TeiserverTestLib.conn_setup()
    end

    test "cannot start viewing as another user", %{conn: conn} do
      target = AccountFixtures.user_fixture(%{roles: []})

      resp = post(conn, ~p"/view_as/#{target.id}")
      refute get_session(resp, ViewAs.session_key())
    end
  end
end
