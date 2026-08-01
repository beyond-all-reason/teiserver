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
    |> init_test_session(%{})
    |> fetch_cookies()
    |> Controller.fetch_flash([])
    |> AuthPipeline.call(AuthPipeline.init([]))
    |> AuthPlug.call([])
  end

  test "assigns current_user from a verified bearer token", %{conn: conn} do
    user = GeneralTestLib.make_user()
    {:ok, token, _claims} = Guardian.encode_and_sign(user)

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> run()

    assert conn.assigns.current_user.id == user.id
    assert conn.assigns.user_token == token
  end

  test "assigns no user without credentials", %{conn: conn} do
    conn = run(conn)

    assert conn.assigns.current_user == nil
    assert conn.assigns.totp_status == nil
  end

  # The bearer path must not shadow the long lived remember me cookie the web
  # session relies on
  test "falls back to the remember me cookie", %{conn: conn} do
    user = GeneralTestLib.make_user()
    {:ok, token, _claims} = Guardian.encode_and_sign(user)

    conn =
      conn
      |> put_req_cookie("guardian_default_token", token)
      |> run()

    assert conn.assigns.current_user.id == user.id
  end

  test "ignores an unparseable bearer token", %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "Bearer nonsense")
      |> run()

    assert conn.assigns.current_user == nil
  end

  test "signs out a user restricted from logging in", %{conn: conn} do
    user = GeneralTestLib.make_user(%{"restrictions" => ["Login"]})
    {:ok, token, _claims} = Guardian.encode_and_sign(user)

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> run()

    assert conn.assigns.current_user == nil
    assert conn.halted or conn.status == 302
  end

  test "signs out a smurf", %{conn: conn} do
    origin = GeneralTestLib.make_user()
    smurf = GeneralTestLib.make_user()
    {:ok, smurf} = Account.update_user_smurf(smurf, %{smurf_of_id: origin.id})
    {:ok, token, _claims} = Guardian.encode_and_sign(smurf)

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> run()

    assert conn.assigns.current_user == nil
  end
end
