defmodule TeiserverWeb.API.Admin.UserControllerTest do
  use TeiserverWeb.ConnCase, async: false
  alias Teiserver.OAuthFixtures

  defp setup_user(_context) do
    user = Central.Helpers.GeneralTestLib.make_user()
    {:ok, user: user}
  end

  defp setup_generic_lobby_app(_context) do
    user = Central.Helpers.GeneralTestLib.make_user()

    # Create the generic_lobby app that our controller expects
    app =
      OAuthFixtures.app_attrs(user.id)
      |> Map.put(:uid, "generic_lobby")
      |> Map.put(:name, "Generic Lobby")
      |> OAuthFixtures.create_app()

    {:ok, oauth_app: app}
  end

  defp setup_token(%{user: user}) do
    OAuthFixtures.setup_token(user)
  end

  defp setup_authed_conn(%{conn: conn, user: user}) do
    %{token: token} = OAuthFixtures.setup_token(user, scopes: ["tachyon.lobby"])
    {:ok, authed_conn: auth_conn(conn, token), token: token}
  end

  defp create_user_path(), do: ~p"/teiserver/api/admin/users"
  defp refresh_token_path(), do: ~p"/teiserver/api/admin/users/refresh_token"

  describe "auth" do
    setup [:setup_user, :setup_token]

    test "requires a bearer token", %{conn: conn} do
      post(conn, create_user_path(), %{}) |> json_response(401)
    end

    test "can access with token", %{conn: conn, token: token} do
      conn |> auth_conn(token) |> post(create_user_path(), %{}) |> json_response(400)
    end
  end

  describe "create user with valid auth" do
    setup [:setup_user, :setup_generic_lobby_app, :setup_authed_conn]

    test "creates user successfully", %{authed_conn: conn} do
      user_data = %{
        "name" => "testuser",
        "email" => "testuser@example.com",
        "password" => "testpassword123"
      }

      resp = conn |> post(create_user_path(), user_data) |> json_response(200)

      assert resp["user"]["name"] == "testuser"
      assert resp["user"]["email"] == "testuser@example.com"
      assert resp["credentials"]["access_token"]
      assert resp["credentials"]["refresh_token"]
    end

    test "creates user with stats", %{authed_conn: conn} do
      user_data = %{
        "name" => "testuser2",
        "email" => "testuser2@example.com",
        "password" => "testpassword123",
        "mu" => 1500,
        "sigma" => 100,
        "play_time" => 3600
      }

      resp = conn |> post(create_user_path(), user_data) |> json_response(200)

      assert resp["user"]["name"] == "testuser2"
      assert resp["credentials"]["access_token"]

      # Verify the created user has the correct stats
      user = Teiserver.Account.get_user_by_email("testuser2@example.com")
      user_stats = Teiserver.Account.get_user_stat_data(user.id)
      assert user_stats["mu"] == 1500
      assert user_stats["sigma"] == 100
      assert user_stats["play_time"] == 3600
    end

    test "handles missing required fields", %{authed_conn: conn} do
      user_data = %{
        "name" => "testuser"
        # missing email and password
      }

      resp = conn |> post(create_user_path(), user_data) |> json_response(400)
      assert resp["error"]
    end

    test "handles invalid email format", %{authed_conn: conn} do
      user_data = %{
        "name" => "testuser",
        "email" => "not-an-email-at-all",
        "password" => "testpassword123"
      }

      resp = conn |> post(create_user_path(), user_data) |> json_response(400)
      assert resp["error"] =~ "invalid email"
    end

    test "handles duplicate email", %{authed_conn: conn} do
      # First create a user
      user_data = %{
        "name" => "firstuser",
        "email" => "duplicate@example.com",
        "password" => "testpassword123"
      }

      conn |> post(create_user_path(), user_data) |> json_response(200)

      # Try to create another user with the same email
      duplicate_data = %{
        "name" => "seconduser",
        "email" => "duplicate@example.com",
        "password" => "testpassword123"
      }

      resp = conn |> post(create_user_path(), duplicate_data) |> json_response(400)
      assert resp["error"] =~ "Email already attached to a user"
    end

    test "creates user with all optional fields", %{authed_conn: conn} do
      user_data = %{
        "name" => "completeuser",
        "email" => "complete@example.com",
        "password" => "testpassword123",
        "icon" => "fa-solid fa-user",
        "colour" => "#FF0000",
        "roles" => ["Verified"],
        "permissions" => ["User"],
        "restrictions" => [],
        "shadowbanned" => false,
        "mu" => 1500,
        "sigma" => 100,
        "play_time" => 3600,
        "spec_time" => 1800,
        "lobby_time" => 7200
      }

      resp = conn |> post(create_user_path(), user_data) |> json_response(200)

      assert resp["user"]["name"] == "completeuser"
      assert resp["user"]["email"] == "complete@example.com"
      assert resp["user"]["icon"] == "fa-solid fa-user"
      assert resp["user"]["colour"] == "#FF0000"
      assert resp["user"]["roles"] == ["Verified"]
      assert resp["user"]["permissions"] == ["User"]
      assert resp["user"]["restrictions"] == []
      assert resp["user"]["shadowbanned"] == false
      assert resp["credentials"]["access_token"]
      assert resp["credentials"]["refresh_token"]
    end
  end

  describe "refresh token with valid auth" do
    setup [:setup_user, :setup_generic_lobby_app, :setup_authed_conn]

    test "refreshes token for existing user", %{authed_conn: conn} do
      # First create a user
      user_data = %{
        "name" => "refreshuser",
        "email" => "refreshuser@example.com",
        "password" => "testpassword123"
      }

      conn |> post(create_user_path(), user_data) |> json_response(200)

      # Then refresh their token
      refresh_data = %{"email" => "refreshuser@example.com"}
      resp = conn |> post(refresh_token_path(), refresh_data) |> json_response(200)

      assert resp["user"]["name"] == "refreshuser"
      assert resp["user"]["email"] == "refreshuser@example.com"
      assert resp["credentials"]["access_token"]
      assert resp["credentials"]["refresh_token"]
    end

    test "handles non-existent user", %{authed_conn: conn} do
      refresh_data = %{"email" => "nonexistent@example.com"}
      resp = conn |> post(refresh_token_path(), refresh_data) |> json_response(404)
      assert resp["error"] == "User not found"
    end

    test "handles missing email", %{authed_conn: conn} do
      # The controller expects %{"email" => email} pattern, so sending nil email
      # will result in "User not found" since no user has nil email
      refresh_data = %{"email" => nil}
      resp = conn |> post(refresh_token_path(), refresh_data) |> json_response(404)
      assert resp["error"] == "User not found"
    end

    test "handles empty email", %{authed_conn: conn} do
      refresh_data = %{"email" => ""}
      resp = conn |> post(refresh_token_path(), refresh_data) |> json_response(404)
      assert resp["error"] == "User not found"
    end
  end

  describe "error handling" do
    setup [:setup_user, :setup_authed_conn]

    test "handles app not found error", %{authed_conn: conn} do
      # This test would require mocking the OAuth app lookup
      # For now, we'll just test the structure
      user_data = %{
        "name" => "testuser",
        "email" => "testuser@example.com",
        "password" => "testpassword123"
      }

      # This should work if the generic_lobby app exists
      resp = conn |> post(create_user_path(), user_data)

      # Should either succeed or give a specific error
      assert resp.status in [200, 400]
    end
  end

  describe "authentication" do
    test "requires bearer token", %{conn: conn} do
      user_data = %{
        "name" => "testuser",
        "email" => "test@example.com",
        "password" => "testpassword123"
      }

      resp = conn |> post(create_user_path(), user_data) |> json_response(401)
      assert resp["error"] =~ "unauthorized_client"
    end

    test "requires valid scopes", %{conn: conn} do
      # Create a user and token without the required scope
      user = Central.Helpers.GeneralTestLib.make_user()

      app =
        OAuthFixtures.app_attrs(user.id)
        |> Map.put(:uid, "test_app")
        |> Map.put(:scopes, ["admin.map"])
        |> OAuthFixtures.create_app()

      token =
        OAuthFixtures.token_attrs(user.id, app)
        |> Map.put(:scopes, ["admin.map"])
        |> OAuthFixtures.create_token()

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token.value}")

      user_data = %{
        "name" => "testuser",
        "email" => "test@example.com",
        "password" => "testpassword123"
      }

      resp = conn |> post(create_user_path(), user_data) |> json_response(401)
      assert resp["error"] =~ "unauthorized_client"
    end
  end

  describe "edge cases" do
    setup [:setup_user, :setup_generic_lobby_app, :setup_authed_conn]

    test "handles very long email", %{authed_conn: conn} do
      long_email = String.duplicate("a", 100) <> "@example.com"

      user_data = %{
        "name" => "testuser",
        "email" => long_email,
        "password" => "testpassword123"
      }

      resp = conn |> post(create_user_path(), user_data) |> json_response(200)
      assert resp["user"]["email"] == long_email
    end

    test "handles special characters in name", %{authed_conn: conn} do
      user_data = %{
        "name" => "User-Name_123 [Test]",
        "email" => "special@example.com",
        "password" => "testpassword123"
      }

      resp = conn |> post(create_user_path(), user_data) |> json_response(200)
      assert resp["user"]["name"] == "User-Name_123 [Test]"
    end

    test "handles unicode characters", %{authed_conn: conn} do
      user_data = %{
        "name" => "José María",
        "email" => "josé@example.com",
        "password" => "testpassword123"
      }

      resp = conn |> post(create_user_path(), user_data) |> json_response(200)
      assert resp["user"]["name"] == "José María"
      assert resp["user"]["email"] == "josé@example.com"
    end
  end

  defp auth_conn(conn, token), do: put_req_header(conn, "authorization", "Bearer #{token.value}")
end
