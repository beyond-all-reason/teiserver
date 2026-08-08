defmodule Teiserver.Account.AuthPlugTest do
  alias Phoenix.Controller
  alias Teiserver.Account
  alias Teiserver.Account.AuthPipeline
  alias Teiserver.Account.AuthPlug
  alias Teiserver.Account.Guardian
  alias Teiserver.Helpers.GeneralTestLib

  use TeiserverWeb.ConnCase, async: false

  # AuthPlug always runs behind the :browser pipeline, which has already set up
  # the session, cookies and flash
  defp run(conn) do
    conn
    |> fetch_cookies()
    |> Controller.fetch_flash([])
    |> AuthPipeline.call(AuthPipeline.init([]))
    |> AuthPlug.call([])
  end

  defp with_session_token(conn, user) do
    {:ok, token, _claims} = Guardian.encode_and_sign(user)
    init_test_session(conn, %{"guardian_default_token" => token})
  end

  test "assigns current_user from the session", %{conn: conn} do
    user = GeneralTestLib.make_user()

    conn =
      conn
      |> with_session_token(user)
      |> run()

    assert conn.assigns.current_user.id == user.id
    assert conn.assigns.user_token != ""
  end

  test "assigns no user without credentials", %{conn: conn} do
    conn =
      conn
      |> init_test_session(%{})
      |> run()

    assert conn.assigns.current_user == nil
    assert conn.assigns.totp_status == nil
  end

  # The session is short lived, the remember me cookie is what keeps a browser
  # logged in across sessions
  test "falls back to the remember me cookie", %{conn: conn} do
    user = GeneralTestLib.make_user()
    {:ok, token, _claims} = Guardian.encode_and_sign(user)

    conn =
      conn
      |> init_test_session(%{})
      |> put_req_cookie("guardian_default_token", token)
      |> run()

    assert conn.assigns.current_user.id == user.id
  end

  # Bearer tokens are handled by the api pipeline, the browser must not care
  test "ignores an authorization header", %{conn: conn} do
    user = GeneralTestLib.make_user()
    {:ok, token, _claims} = Guardian.encode_and_sign(user)

    conn =
      conn
      |> init_test_session(%{})
      |> put_req_header("authorization", "Bearer #{token}")
      |> run()

    assert conn.assigns.current_user == nil
  end

  test "ignores an unparseable remember me cookie", %{conn: conn} do
    conn =
      conn
      |> init_test_session(%{})
      |> put_req_cookie("guardian_default_token", "nonsense")
      |> run()

    assert conn.assigns.current_user == nil
  end

  test "signs out a user restricted from logging in", %{conn: conn} do
    user = GeneralTestLib.make_user(%{"restrictions" => ["Login"]})

    conn =
      conn
      |> with_session_token(user)
      |> run()

    assert conn.assigns.current_user == nil
    assert redirected_to(conn) == ~p"/logout"
  end

  test "signs out a smurf", %{conn: conn} do
    origin = GeneralTestLib.make_user()
    smurf = GeneralTestLib.make_user()
    {:ok, smurf} = Account.update_user_smurf(smurf, %{smurf_of_id: origin.id})

    conn =
      conn
      |> with_session_token(smurf)
      |> run()

    assert conn.assigns.current_user == nil
    assert redirected_to(conn) == ~p"/logout"
  end
end
