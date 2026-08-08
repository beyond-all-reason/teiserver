defmodule TeiserverWeb.API.BattleControllerTest do
  alias Teiserver.Account.Guardian
  alias Teiserver.Helpers.GeneralTestLib

  use TeiserverWeb.ConnCase, async: false

  # The :token_api pipeline must answer as an api, not send the caller off to
  # the login page like the browser pipeline does
  describe "unauthenticated" do
    test "answers with json rather than a redirect", %{conn: conn} do
      conn = post(conn, ~p"/teiserver/api/battle/create", %{})

      assert json_response(conn, 401) == %{"error" => "unauthenticated"}
    end

    test "rejects a garbage bearer token with json", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer nonsense")
        |> post(~p"/teiserver/api/battle/create", %{})

      assert json_response(conn, 401) == %{"error" => "invalid_token"}
    end
  end

  describe "authenticated" do
    # The bearer token gets us a current_user, which is what the permission
    # check needs. Without the permission it is a json 403, not a redirect to
    # the home page like the browser would get
    test "answers a missing permission with json", %{conn: conn} do
      user = GeneralTestLib.make_user()
      {:ok, token, _claims} = Guardian.encode_and_sign(user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/teiserver/api/battle/create", %{})

      assert json_response(conn, 403) == %{"error" => "forbidden"}
    end
  end
end
