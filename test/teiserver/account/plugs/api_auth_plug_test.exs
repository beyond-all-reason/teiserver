defmodule Teiserver.Account.ApiAuthPlugTest do
  alias Phoenix.Controller
  alias Teiserver.Account
  alias Teiserver.Account.ApiAuthPlug
  alias Teiserver.Account.Guardian
  alias Teiserver.Helpers.GeneralTestLib

  use TeiserverWeb.ConnCase, async: false

  defp run(conn) do
    conn
    |> Controller.accepts(["json"])
    |> ApiAuthPlug.call(ApiAuthPlug.init([]))
  end

  defp with_bearer_token(conn, user) do
    {:ok, token, _claims} = Guardian.encode_and_sign(user)
    put_req_header(conn, "authorization", "Bearer #{token}")
  end

  test "assigns current_user from a verified bearer token", %{conn: conn} do
    user = GeneralTestLib.make_user()

    conn =
      conn
      |> with_bearer_token(user)
      |> run()

    assert conn.assigns.current_user.id == user.id
    refute conn.halted
  end

  test "rejects a request with no credentials", %{conn: conn} do
    conn = run(conn)

    assert conn.halted
    assert json_response(conn, 401) == %{"error" => "unauthenticated"}
  end

  # Sessions and remember me cookies belong to the browser, the api must not
  # accept them
  test "ignores the remember me cookie", %{conn: conn} do
    user = GeneralTestLib.make_user()
    {:ok, token, _claims} = Guardian.encode_and_sign(user)

    conn =
      conn
      |> put_req_cookie("guardian_default_token", token)
      |> run()

    assert json_response(conn, 401) == %{"error" => "unauthenticated"}
  end

  test "rejects an unparseable bearer token", %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "Bearer nonsense")
      |> run()

    assert json_response(conn, 401) == %{"error" => "invalid_token"}
  end

  test "rejects an empty bearer token", %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "Bearer    ")
      |> run()

    assert json_response(conn, 401) == %{"error" => "invalid_token"}
  end

  test "rejects a refresh token", %{conn: conn} do
    user = GeneralTestLib.make_user()
    {:ok, token, _claims} = Guardian.encode_and_sign(user, %{"typ" => "refresh"})

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> run()

    assert json_response(conn, 401) == %{"error" => "invalid_token"}
  end

  test "rejects a user restricted from logging in", %{conn: conn} do
    user = GeneralTestLib.make_user(%{"restrictions" => ["Login"]})

    conn =
      conn
      |> with_bearer_token(user)
      |> run()

    assert json_response(conn, 403) == %{"error" => "account_restricted"}
  end

  test "rejects a smurf", %{conn: conn} do
    origin = GeneralTestLib.make_user()
    smurf = GeneralTestLib.make_user()
    {:ok, smurf} = Account.update_user_smurf(smurf, %{smurf_of_id: origin.id})

    conn =
      conn
      |> with_bearer_token(smurf)
      |> run()

    assert json_response(conn, 403) == %{"error" => "account_restricted"}
  end
end
