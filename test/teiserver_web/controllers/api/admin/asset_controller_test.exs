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

  defp update_map_path(), do: ~p"/teiserver/api/admin/assets/update_maps"

  describe "auth" do
    setup [:setup_user, :setup_token]

    test "requires a bearer token", %{conn: conn} do
      post(conn, update_map_path()) |> json_response(401)
    end

    test "can access with token", %{conn: conn, token: token} do
      conn |> auth_conn(token) |> post(update_map_path()) |> json_response(401)
    end
  end

  describe "maps with valid auth" do
    setup [:setup_user, :setup_authed_conn]

    test "update ok", %{authed_conn: conn} do
      data = %{
        maps: [
          %{
            springName: "Quicksilver Remake 1.24",
            displayName: "Quicksilver",
            thumbnail: "http://blah.com/qs.jpg",
            matchmakingQueues: [],
            modoptions: %{},
            startboxesSet: []
          }
        ]
      }

      resp = conn |> post(update_map_path(), data) |> json_response(201)
      assert resp == %{"status" => "success", "created_count" => 1, "deleted_count" => 0}
    end

    test "invalid payload, missing spring name", %{authed_conn: conn} do
      data = %{
        maps: [
          %{
            displayName: "Quicksilver",
            thumbnail: "http://blah.com/qs.jpg"
          }
        ]
      }

      conn |> post(update_map_path(), data) |> json_response(400)
    end
  end

  defp auth_conn(conn, token), do: put_req_header(conn, "authorization", "Bearer #{token.value}")
end
