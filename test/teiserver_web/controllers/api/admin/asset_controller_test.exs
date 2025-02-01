defmodule TeiserverWeb.API.Admin.AssetControllerTest do
  use TeiserverWeb.ConnCase, async: false
  alias Teiserver.OAuthFixtures

  defp setup_user(_context) do
    user = Central.Helpers.GeneralTestLib.make_user()
    {:ok, user: user}
  end

  defp setup_token(%{user: user}) do
    OAuthFixtures.setup_token(user)
  end

  defp setup_authed_conn(%{conn: conn, user: user}) do
    %{token: token} = OAuthFixtures.setup_token(user, scopes: ["admin.map"])
    {:ok, authed_conn: auth_conn(conn, token), token: token}
  end

  defp assets_path(), do: ~p"/teiserver/api/admin/assets"

  describe "auth" do
    setup [:setup_user, :setup_token]

    test "requires a bearer token", %{conn: conn} do
      post(conn, assets_path()) |> json_response(401)
    end

    test "can access with token", %{conn: conn, token: token} do
      conn |> auth_conn(token) |> post(assets_path()) |> json_response(401)
    end
  end

  describe "maps with valid auth" do
    setup [:setup_user, :setup_authed_conn]

    test "placeholder", %{authed_conn: conn} do
      conn |> post(assets_path()) |> json_response(501)
    end
  end

  defp auth_conn(conn, token), do: put_req_header(conn, "authorization", "Bearer #{token.value}")
end
