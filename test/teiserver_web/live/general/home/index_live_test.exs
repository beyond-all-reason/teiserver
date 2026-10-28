defmodule TeiserverWeb.General.Home.IndexLiveTest do
  @moduledoc false

  alias Teiserver.Account.User
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.Repo
  alias Teiserver.TeiserverTestLib

  use TeiserverWeb.ConnCase

  import Phoenix.LiveViewTest

  defp auth_setup(_context) do
    GeneralTestLib.conn_setup()
    |> TeiserverTestLib.conn_setup()
  end

  describe "Visit index without authentication" do
    test "index get", %{conn: conn} do
      conn = get(conn, ~p"/")
      assert redirected_to(conn) == ~p"/login"
    end

    test "index live", %{conn: conn} do
      {:error, {:redirect, resp}} = live(conn, ~p"/")

      assert resp.to == ~p"/login"
    end
  end

  describe "Auth" do
    setup [:auth_setup]

    test "index", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/")

      assert html =~ "Logout"
      assert html =~ "Account"
    end
  end

  describe "GDPR forget" do
    setup [:auth_setup]

    test "users set to forget cannot access other pages", %{conn: conn, user: user} do
      # First ensure we can access the homepage
      {:ok, _index_live, _html} = live(conn, ~p"/")

      # Now we set the user to be forgotten
      {:ok, _new_user} =
        user
        |> User.set_gdpr_forget_changeset(%{gdpr_forget_after: DateTime.utc_now()})
        |> Repo.update()

      # Now when we go to access the homepage it should redirect to the logout page
      {:error, {:redirect, %{to: "/logout", flash: _flash}}} = live(conn, ~p"/")

      # Try a different page, it's not just the homepage this happens with
      {:error, {:redirect, %{to: "/logout", flash: _flash}}} =
        live(conn, ~p"/account/relationship")
    end
  end

  # We had an issue where an unauthenticated user would visit a page and something
  # would try to render expecting a scope. It was fixed correctly but caused a bad server
  # deployment because the supervisor tree would be restarted after a certain number of errors
  # in quick succession.
  describe "unauth scope test" do
    # Without the fix, this test would fail
    test "unauth access redirects without error" do
      {:ok, kw} = GeneralTestLib.conn_setup([], [:no_login])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/account/relationship")
      assert path == ~p"/login"
    end

    test "page loads correctly when logged in" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Verified"])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:ok, _html, _live} = live(conn, ~p"/account/relationship")
    end
  end
end
