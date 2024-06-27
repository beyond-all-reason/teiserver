defmodule TeiserverWeb.OAuth.CodeControllerTest do
  use TeiserverWeb.ConnCase
  alias Central.Helpers.GeneralTestLib
  alias Teiserver.OAuth
  alias Teiserver.Test.Support.OAuth, as: OAuthTest

  defp get_valid_data(%{app: app, code: code, code_attrs: code_attrs}) do
    %{
      grant_type: "authorization_code",
      code: code.value,
      redirect_uri: code.redirect_uri,
      client_id: app.uid,
      code_verifier: code_attrs.verifier
    }
  end

  defp setup_conn(_context) do
    conn = Phoenix.ConnTest.build_conn()
    user = GeneralTestLib.make_user()
    {:ok, conn: conn, user: user}
  end

  defp setup_app(context) do
    {:ok, app} =
      OAuth.create_application(%{
        name: "testing app",
        uid: "test_app_uid",
        owner_id: context[:user].id,
        scopes: ["tachyon.lobby"],
        redirect_uris: ["http://127.0.0.1:6789/oauth/callback"]
      })

    %{app: app}
  end

  defp setup_code(context) do
    {:ok, code, attrs} = OAuthTest.create_code(context[:user], context[:app])

    %{code: code, code_attrs: attrs}
  end

  defp setup_autohost(_context) do
    {:ok, autohost} = Teiserver.Autohost.create_autohost(%{name: "testing_autohost"})
    %{autohost: autohost}
  end

  defp setup_credential(%{autohost: autohost, app: app}) do
    secret = "very-much-secret"
    {:ok, cred} = OAuth.create_credentials(app, autohost, "cred-client-id", secret)
    %{credential: cred, credential_secret: secret}
  end

  defp setup_token(context) do
    {:ok, token} = OAuth.create_token(context[:user], context[:app])
    %{token: token}
  end

  describe "exchange code for token" do
    setup [:setup_conn, :setup_app, :setup_code]

    test "works with the right params", %{conn: conn} = setup_data do
      data = get_valid_data(setup_data)

      resp = post(conn, ~p"/oauth/token", data)
      json_resp = json_response(resp, 200)
      assert is_binary(json_resp["access_token"]), "has access_token"
      assert is_integer(json_resp["expires_in"]), "has expires_in"
      assert is_binary(json_resp["refresh_token"]), "has refresh_token"
      assert json_resp["token_type"] == "Bearer", "bearer token type"

      # within 5 seconds in case extremely slow test
      assert_in_delta(json_resp["expires_in"], 60 * 30, 5, "valid for 30 minutes")

      resp2 = post(conn, ~p"/oauth/token", data)

      # code is now used up and invalid
      assert json_response(resp2, 400) == %{
               "error_description" => "invalid request",
               "error" => "invalid_request"
             }
    end

    test "must provide grant_type", %{conn: conn} = setup_data do
      data = get_valid_data(setup_data) |> Map.drop([:grant_type])
      resp = post(conn, ~p"/oauth/token", data)
      assert %{"error" => "invalid_request"} = json_response(resp, 400)
    end

    test "must provide code", %{conn: conn} = setup_data do
      data = get_valid_data(setup_data) |> Map.drop([:code])
      resp = post(conn, ~p"/oauth/token", data)
      assert %{"error" => "invalid_request"} = json_response(resp, 400)
    end

    test "must provide redirect_uri", %{conn: conn} = setup_data do
      data = get_valid_data(setup_data) |> Map.drop([:redirect_uri])
      resp = post(conn, ~p"/oauth/token", data)
      assert %{"error" => "invalid_request"} = json_response(resp, 400)
    end

    test "must provide client_id", %{conn: conn} = setup_data do
      data = get_valid_data(setup_data) |> Map.drop([:client_id])
      resp = post(conn, ~p"/oauth/token", data)
      assert %{"error" => "invalid_request"} = json_response(resp, 400)
    end

    test "client_id must match", %{conn: conn} = setup_data do
      {:ok, other_app} =
        OAuth.create_application(%{
          name: "another testing app",
          uid: "another_test_app_uid",
          owner_id: setup_data[:user].id,
          scopes: ["tachyon.lobby"],
          redirect_uris: ["http://127.0.0.1:6789/oauth/callback"]
        })

      data = get_valid_data(setup_data) |> Map.put(:client_id, other_app.uid)
      resp = post(conn, ~p"/oauth/token", data)
      assert %{"error" => "invalid_request"} = json_response(resp, 400)
    end

    # Note: verifier code and redirect URI matching is tested in OAuth.exchange_code
    # so they are omitted here
  end

  describe "get token from client credentials" do
    setup [:setup_conn, :setup_app, :setup_autohost, :setup_credential]

    test "it works with the right params", %{
      conn: conn,
      credential: credential,
      credential_secret: secret
    } do
      data = %{
        grant_type: "client_credentials",
        client_id: credential.client_id,
        client_secret: secret
      }

      resp = post(conn, ~p"/oauth/token", data)
      json_resp = json_response(resp, 200)
      assert is_binary(json_resp["access_token"]), "has access_token"
      assert is_integer(json_resp["expires_in"]), "has expires_in"
      assert is_binary(json_resp["refresh_token"]), "has refresh_token"
      assert json_resp["token_type"] == "Bearer", "bearer token type"
    end

    test "must provide correct secret", %{conn: conn, credential: credential} do
      data = %{
        grant_type: "client_credentials",
        client_id: credential.client_id,
        client_secret: "definitely-not-the-correct-secret"
      }

      resp = post(conn, ~p"/oauth/token", data)
      json_response(resp, 400)
    end

    test "can also use basic auth",
         %{conn: conn, credential: credential, credential_secret: secret} do
      data = %{grant_type: "client_credentials"}
      auth_header = Plug.BasicAuth.encode_basic_auth(credential.client_id, secret)

      conn =
        conn
        |> put_req_header("authorization", auth_header)

      resp = post(conn, ~p"/oauth/token", data)
      json_resp = json_response(resp, 200)
      assert is_binary(json_resp["access_token"]), "has access_token"
      assert is_integer(json_resp["expires_in"]), "has expires_in"
      assert is_binary(json_resp["refresh_token"]), "has refresh_token"
      assert json_resp["token_type"] == "Bearer", "bearer token type"
    end

    test "basic auth check", %{conn: conn, credential: credential} do
      data = %{grant_type: "client_credentials"}
      auth_header = Plug.BasicAuth.encode_basic_auth(credential.client_id, "lolnope")

      conn =
        conn
        |> put_req_header("authorization", auth_header)

      resp = post(conn, ~p"/oauth/token", data)
      json_response(resp, 400)
    end
  end

  describe "refresh token" do
    setup [:setup_conn, :setup_app, :setup_token]

    test "works", %{conn: conn} = setup_data do
      data = %{
        grant_type: "refresh_token",
        client_id: setup_data[:app].uid,
        refresh_token: setup_data[:token].refresh_token.value
      }

      resp = post(conn, ~p"/oauth/token", data)
      assert json_resp = json_response(resp, 200)
      assert is_binary(json_resp["access_token"]), "has access_token"
      assert is_integer(json_resp["expires_in"]), "has expires_in"
      assert is_binary(json_resp["refresh_token"]), "has refresh_token"
      assert json_resp["token_type"] == "Bearer", "bearer token type"

      resp2 = post(conn, ~p"/oauth/token", data)

      # refresh token is now used up and invalid
      assert json_response(resp2, 400) == %{
               "error_description" => "invalid request",
               "error" => "invalid_request"
             }
    end

    test "client_id must match", %{conn: conn} = setup_data do
      {:ok, other_app} =
        OAuth.create_application(%{
          name: "another testing app",
          uid: "another_test_app_uid",
          owner_id: setup_data[:user].id,
          scopes: ["tachyon.lobby"],
          redirect_uris: ["http://127.0.0.1:6789/oauth/callback"]
        })

      data = %{
        grant_type: "refresh_token",
        client_id: other_app.uid,
        refresh_token: setup_data[:token].refresh_token.value
      }

      resp = post(conn, ~p"/oauth/token", data)
      assert %{"error" => "invalid_request"} = json_response(resp, 400)
    end
  end

  describe "medatata endpoint" do
    setup :setup_conn

    test "can query oauth metadata", %{conn: conn} do
      resp = json_response(get(conn, ~p"/.well-known/oauth-authorization-server"), 200)

      assert resp == %{
               "issuer" => "https://beyondallreason.info",
               "authorization_endpoint" => "https://beyondallreason.info/oauth/authorize",
               "token_endpoint" => "https://beyondallreason.info/oauth/token",
               "token_endpoint_auth_methods_supported" => [
                 "none",
                 "client_secret_post",
                 "client_secret_basic"
               ],
               "grant_types_supported" => [
                 "authorization_code",
                 "refresh_token",
                 "client_credentials"
               ],
               "code_challenge_methods_supported" => ["S256"]
             }
    end
  end
end
