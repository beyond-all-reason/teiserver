defmodule TeiserverWeb.OAuth.UserinfoControllerTest do
  alias Phoenix.ConnTest
  alias Teiserver.Account.Auth
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.OAuth
  alias Teiserver.OAuthFixtures
  use TeiserverWeb.ConnCase

  defp setup_app(_context) do
    {:ok, admin_user} = Auth.add_roles(TeiserverTestLib.new_user().id, ["Admin"])

    {:ok, app} =
      OAuth.create_application(%{
        name: "testing app",
        uid: "test_app_uid",
        owner_id: admin_user.id,
        scopes: OAuth.allowed_scopes(),
        redirect_uris: ["http://127.0.0.1:6789/oauth/callback"]
      })

    %{app: app}
  end

  defp setup_conn(_context) do
    conn = ConnTest.build_conn()
    user = GeneralTestLib.make_user()
    {:ok, conn: conn, user: user}
  end

  setup [:setup_conn, :setup_app]

  test "requires a token", %{conn: conn} do
    resp = get(conn, ~p"/oauth/userinfo")
    assert resp.status == 401
  end

  test "can get user id", %{conn: conn, user: user, app: app} do
    token =
      OAuthFixtures.token_attrs(user, app)
      |> Map.put(:scopes, [])
      |> OAuthFixtures.create_token()

    resp =
      conn
      |> put_req_header("authorization", "Bearer #{token.value}")
      |> get(~p"/oauth/userinfo")

    assert json_response(resp, 200)["sub"] == to_string(user.id)
  end
end
