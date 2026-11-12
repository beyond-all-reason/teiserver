defmodule TeiserverWeb.OAuth.CodeControllerTest do
  alias Phoenix.ConnTest
  alias Teiserver.Account
  alias Teiserver.Bot
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.OAuth
  alias Teiserver.OAuthFixtures
  alias Teiserver.Player
  alias Teiserver.Steam
  alias Teiserver.Support.Tachyon
  alias TeiserverWeb.Endpoint

  use TeiserverWeb.ConnCase

  import Mock

  defp get_valid_data(%{app: app, code: code, code_attrs: code_attrs}) do
    %{
      grant_type: "authorization_code",
      code: code.value,
      redirect_uri: code.redirect_uri,
      client_id: app.uid,
      code_verifier: code_attrs._verifier
    }
  end

  defp setup_conn(_context) do
    conn = ConnTest.build_conn()
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
    attrs = OAuthFixtures.code_attrs(context[:user], context[:app])
    code = OAuthFixtures.create_code(attrs)

    %{code: code, code_attrs: attrs}
  end

  defp setup_bot(_context) do
    {:ok, bot} = Bot.create_bot(%{name: "testing_bot"})
    %{bot: bot}
  end

  defp setup_credential(%{bot: bot, app: app}) do
    secret = "very-much-secret"
    {:ok, cred} = OAuth.create_credentials(app, bot, "cred-client-id", secret)
    %{credential: cred, credential_secret: secret}
  end

  defp setup_token(context) do
    {:ok, token} = OAuth.create_token(context[:user], context[:app], scopes: context[:app].scopes)
    %{token: token}
  end

  # Steam token exchange
  defp exchange_data(app, overrides \\ %{}) do
    Map.merge(
      %{
        client_id: app.uid,
        grant_type: "urn:ietf:params:oauth:grant-type:token-exchange",
        scope: "tachyon.lobby",
        requested_token_type: "urn:ietf:params:oauth:token-type:access_token",
        subject_token_type: "urn:tachyon:oauth:token-type:steam_session_ticket",
        subject_token: "1234567890abcde"
      },
      overrides
    )
  end

  defp steam_mock(steam_id, overrides \\ []) do
    Keyword.merge(
      [
        authenticate_ticket: fn _ticket -> {:ok, steam_id} end,
        check_app_ownership: fn _steam_id -> :ok end,
        get_persona_name: fn _steam_id -> {:ok, "SteamUser"} end
      ],
      overrides
    )
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
      assert %{
               "error" => "invalid_request",
               "error_description" => description
             } = json_response(resp2, 400)

      assert description =~ "no authorization code"
    end

    test "can use basic auth to exchange", %{conn: conn} = setup_data do
      data = get_valid_data(setup_data)

      client_id = data.client_id
      data = Map.drop(data, [:client_id])
      auth_header = OAuth.encode_basic_auth(client_id, "")

      resp =
        conn
        |> put_req_header("authorization", auth_header)
        |> post(~p"/oauth/token", data)

      json_resp = json_response(resp, 200)
      assert is_binary(json_resp["access_token"]), "has access_token"
    end

    test "can use a client secret instead of PKCE", ctx do
      app =
        OAuthFixtures.app_attrs(ctx[:user].id)
        |> Map.put(:confidential?, true)
        |> OAuthFixtures.create_app()

      code =
        OAuthFixtures.code_attrs(ctx[:user], app)
        |> Map.drop([:challenge, :challenge_method])
        |> OAuthFixtures.create_code()

      data = %{
        grant_type: "authorization_code",
        code: code.value,
        redirect_uri: code.redirect_uri,
        client_id: app.uid,
        client_secret: app.plain_text_secret
      }

      resp = post(ctx[:conn], ~p"/oauth/token", data) |> json_response(200)
      assert resp["token_type"] == "Bearer", "bearer token type"
    end

    test "must use client secret for confidential clients", ctx do
      app =
        OAuthFixtures.app_attrs(ctx[:user].id)
        |> Map.put(:confidential?, true)
        |> OAuthFixtures.create_app()

      code =
        OAuthFixtures.code_attrs(ctx[:user], app)
        |> Map.drop([:challenge, :challenge_method])
        |> OAuthFixtures.create_code()

      data = %{
        grant_type: "authorization_code",
        code: code.value,
        redirect_uri: code.redirect_uri,
        client_id: app.uid
        # ! no client secret
      }

      resp = post(ctx[:conn], ~p"/oauth/token", data) |> json_response(400)
      assert resp["error_description"] =~ "missing required client_secret"
    end

    test "must not provide client_id twice", %{conn: conn} = setup_data do
      data = get_valid_data(setup_data)

      client_id = data.client_id
      auth_header = OAuth.encode_basic_auth(client_id, "")

      resp =
        conn
        |> put_req_header("authorization", auth_header)
        |> post(~p"/oauth/token", data)

      json_response(resp, 400)
    end

    test "must provide correct grant type", %{conn: conn} = setup_data do
      data = get_valid_data(setup_data) |> Map.put(:grant_type, "invalid-grant-type")
      resp = post(conn, ~p"/oauth/token", data)
      assert %{"error" => "unsupported_grant_type"} = json_response(resp, 400)
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

      assert %{"error" => "invalid_request", "error_description" => description} =
               json_response(resp, 400)

      assert description =~ "code doesn't match application"
    end

    # Note: verifier code and redirect URI matching is tested in OAuth.exchange_code
    # so they are omitted here
  end

  describe "Steam token exchnage" do
    setup do
      original = Application.get_env(:teiserver, Steam)

      Application.put_env(:teiserver, Steam, Keyword.put(original, :api_key, "test-key"))

      on_exit(fn -> Application.put_env(:teiserver, Steam, original) end)

      owner = GeneralTestLib.make_user()

      {:ok, app} =
        OAuth.create_application(%{
          name: "Steam client",
          uid: "steam_test_app",
          owner_id: owner.id,
          scopes: ["tachyon.lobby"]
        })

      {:ok, app: app, steam_id: :rand.uniform(100_000_000)}
    end

    @tag :tachyon
    test "successful exchange", ctx do
      with_mock Steam, [:passthrough], steam_mock(ctx.steam_id) do
        json_resp =
          post(ctx.conn, ~p"/oauth/token", exchange_data(ctx.app))
          |> json_response(200)

        assert json_resp["issued_token_type"] == "urn:ietf:params:oauth:token-type:access_token"
        assert json_resp["scope"] == "tachyon.lobby"
        assert is_binary(json_resp["access_token"]), "has access_token"
        assert is_integer(json_resp["expires_in"]), "has expires_in"
        assert is_binary(json_resp["refresh_token"]), "has refresh_token"
        assert json_resp["token_type"] == "Bearer", "bearer token type"

        {:ok, token} = OAuth.get_valid_token(json_resp["access_token"])

        user = Account.get_user_by_steam_id(ctx.steam_id)

        assert token.owner_id == user.id

        # Can connect via Tachyon
        _client = Tachyon.connect(token)
        assert is_pid(Player.lookup_connection(token.owner_id))
      end
    end

    test "requested_token_type and scope are optional", ctx do
      data =
        ctx.app
        |> exchange_data()
        |> Map.drop([:requested_token_type, :scope])

      with_mock Steam, [:passthrough], steam_mock(ctx.steam_id) do
        json_resp = post(ctx.conn, ~p"/oauth/token", data) |> json_response(200)

        assert json_resp["scope"] == "tachyon.lobby"
      end
    end

    test "Steam users can share a name", ctx do
      GeneralTestLib.make_user(%{"name" => "ExistingName"})

      mock = steam_mock(ctx.steam_id, get_persona_name: fn _id -> {:ok, "ExistingName"} end)

      with_mock Steam, [:passthrough], mock do
        post(ctx.conn, ~p"/oauth/token", exchange_data(ctx.app)) |> json_response(200)
      end

      assert Account.get_user_by_steam_id(ctx.steam_id).name == "ExistingName"
    end

    test "not owning the game", ctx do
      mock =
        steam_mock(ctx.steam_id, check_app_ownership: fn _steam_id -> {:error, :not_owned} end)

      with_mock Steam, [:passthrough], mock do
        assert %{
                 "error" => "invalid_request",
                 "error_description" => "Steam account does not own the game"
               } = post(ctx.conn, ~p"/oauth/token", exchange_data(ctx.app)) |> json_response(400)
      end

      assert Account.get_user_by_steam_id(ctx.steam_id) == nil
    end

    test "publisher banned", ctx do
      mock =
        steam_mock(ctx.steam_id,
          check_app_ownership: fn _steam_id -> {:error, :publisher_banned} end
        )

      with_mock Steam, [:passthrough], mock do
        assert %{
                 "error" => "invalid_request",
                 "error_description" => "Steam account banned"
               } = post(ctx.conn, ~p"/oauth/token", exchange_data(ctx.app)) |> json_response(400)
      end

      assert Account.get_user_by_steam_id(ctx.steam_id) == nil
    end

    test "Steam unavailable", ctx do
      mock =
        steam_mock(ctx.steam_id, authenticate_ticket: fn _ticket -> {:error, :steam_error} end)

      with_mock Steam, [:passthrough], mock do
        assert %{"error" => "temporarily_unavailable"} =
                 post(ctx.conn, ~p"/oauth/token", exchange_data(ctx.app)) |> json_response(503)
      end
    end

    test "unsupported when Steam isn't configured", %{conn: conn, app: app} do
      Application.put_env(
        :teiserver,
        Steam,
        Keyword.put(Application.get_env(:teiserver, Steam), :api_key, nil)
      )

      assert %{"error" => "unsupported_grant_type"} =
               post(conn, ~p"/oauth/token", exchange_data(app)) |> json_response(400)
    end

    test "missing required parameters", %{conn: conn, app: app} do
      for key <- [:subject_token, :subject_token_type, :client_id] do
        data = app |> exchange_data() |> Map.delete(key)

        assert %{"error" => "invalid_request", "error_description" => "missing #{key}"} ==
                 post(conn, ~p"/oauth/token", data) |> json_response(400)
      end
    end

    test "unsupported subject_token_type", %{conn: conn, app: app} do
      data = exchange_data(app, %{subject_token_type: "urn:ietf:params:oauth:token-type:jwt"})

      with_mock Steam, [:passthrough], [] do
        assert %{
                 "error" => "invalid_request",
                 "error_description" => "unsupported subject_token_type"
               } == post(conn, ~p"/oauth/token", data) |> json_response(400)
      end
    end

    test "unsupported requested_token_type", %{conn: conn, app: app} do
      data =
        exchange_data(app, %{requested_token_type: "urn:ietf:params:oauth:token-type:id_token"})

      assert %{
               "error" => "invalid_request",
               "error_description" => "unsupported requested_token_type"
             } == post(conn, ~p"/oauth/token", data) |> json_response(400)
    end

    test "unknown client_id", %{conn: conn, app: app} do
      data = exchange_data(app, %{client_id: "unknown_client"})

      assert %{"error" => "invalid_request"} =
               post(conn, ~p"/oauth/token", data) |> json_response(400)
    end

    test "scope not allowed for the client", %{conn: conn, app: app} do
      data = exchange_data(app, %{scope: "admin.map"})

      assert %{"error" => "invalid_scope"} =
               post(conn, ~p"/oauth/token", data) |> json_response(400)
    end

    test "invalid ticket", ctx do
      mock =
        steam_mock(ctx.steam_id, authenticate_ticket: fn _ticket -> {:error, :invalid_ticket} end)

      with_mock Steam, [:passthrough], mock do
        assert %{
                 "error" => "invalid_request",
                 "error_description" => "invalid Steam session ticket"
               } == post(ctx.conn, ~p"/oauth/token", exchange_data(ctx.app)) |> json_response(400)
      end
    end
  end

  describe "get token from client credentials" do
    setup [:setup_conn, :setup_app, :setup_bot, :setup_credential]

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
      refute Map.has_key?(json_resp, "refresh_token"), "no refresh token"
      assert json_resp["token_type"] == "Bearer", "bearer token type"
    end

    test "must provide correct secret", %{conn: conn, credential: credential} do
      data = %{
        grant_type: "client_credentials",
        client_id: credential.client_id,
        client_secret: "definitely-not-the-correct-secret"
      }

      resp = post(conn, ~p"/oauth/token", data)
      assert %{"error" => "invalid_client"} = json_response(resp, 401)
    end

    test "can also use basic auth",
         %{conn: conn, credential: credential, credential_secret: secret} do
      data = %{grant_type: "client_credentials"}
      auth_header = OAuth.encode_basic_auth(credential.client_id, secret)

      conn =
        conn
        |> put_req_header("authorization", auth_header)

      resp = post(conn, ~p"/oauth/token", data)
      json_resp = json_response(resp, 200)
      assert is_binary(json_resp["access_token"]), "has access_token"
      assert is_integer(json_resp["expires_in"]), "has expires_in"
      refute Map.has_key?(json_resp, "refresh_token"), "no refresh token"
      assert json_resp["token_type"] == "Bearer", "bearer token type"
    end

    test "basic auth check", %{conn: conn, credential: credential} do
      data = %{grant_type: "client_credentials"}
      auth_header = OAuth.encode_basic_auth(credential.client_id, "lolnope")

      conn =
        conn
        |> put_req_header("authorization", auth_header)

      resp = post(conn, ~p"/oauth/token", data)
      json_response(resp, 401)
    end

    test "cannot provide client_id twice", %{
      conn: conn,
      credential: credential,
      credential_secret: secret
    } do
      data = %{grant_type: "client_credentials", client_id: credential.client_id}
      auth_header = OAuth.encode_basic_auth(credential.client_id, secret)

      conn =
        conn
        |> put_req_header("authorization", auth_header)

      resp = post(conn, ~p"/oauth/token", data)
      json_response(resp, 400)
    end

    test "cannot provide client_secret twice", %{
      conn: conn,
      credential: credential,
      credential_secret: secret
    } do
      data = %{grant_type: "client_credentials", client_secret: secret}
      auth_header = OAuth.encode_basic_auth(credential.client_id, secret)

      conn =
        conn
        |> put_req_header("authorization", auth_header)

      resp = post(conn, ~p"/oauth/token", data)
      json_response(resp, 400)
    end

    test "must provide correct scopes", %{conn: conn} = setup_data do
      data = %{
        grant_type: "client_credentials",
        client_id: setup_data.credential.client_id,
        client_secret: setup_data.credential_secret,
        scope: "lolnotascope tachyon.lobby"
      }

      resp = post(conn, ~p"/oauth/token", data)
      assert %{"error" => "invalid_scope"} = json_response(resp, 400)
    end

    test "can provide a specific scope", %{conn: conn} = setup_data do
      data = %{
        grant_type: "client_credentials",
        client_id: setup_data.credential.client_id,
        client_secret: setup_data.credential_secret,
        scope: "tachyon.lobby"
      }

      resp = post(conn, ~p"/oauth/token", data)
      assert %{"token_type" => "Bearer"} = json_response(resp, 200)
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

    test "must provide valid scope", %{conn: conn} = setup_data do
      data = %{
        grant_type: "refresh_token",
        client_id: setup_data[:app].uid,
        refresh_token: setup_data[:token].refresh_token.value,
        scope: "lolscope"
      }

      resp = post(conn, ~p"/oauth/token", data)
      assert %{"error" => "invalid_request"} = json_response(resp, 400)
    end

    # https://datatracker.ietf.org/doc/html/rfc6749#section-3.2.1
    test "confidential client can get refresh token", ctx do
      app =
        OAuthFixtures.app_attrs(ctx[:user].id)
        |> Map.put(:confidential?, true)
        |> OAuthFixtures.create_app()

      {:ok, token} = OAuth.create_token(ctx[:user], app, scopes: app.scopes)

      data = %{
        grant_type: "refresh_token",
        client_id: app.uid,
        client_secret: app.plain_text_secret,
        refresh_token: token.refresh_token.value
      }

      resp = post(ctx[:conn], ~p"/oauth/token", data) |> json_response(200)
      assert resp["token_type"] == "Bearer"
    end
  end

  describe "medatata endpoint" do
    setup :setup_conn

    test "can query oauth metadata", %{conn: conn} do
      resp = json_response(get(conn, ~p"/.well-known/oauth-authorization-server"), 200)
      endpoint = Endpoint.static_url()

      assert resp == %{
               "issuer" => "#{endpoint}",
               "authorization_endpoint" => "#{endpoint}/oauth/authorize",
               "token_endpoint" => "#{endpoint}/oauth/token",
               "token_endpoint_auth_methods_supported" => [
                 "none",
                 "client_secret_post",
                 "client_secret_basic"
               ],
               "userinfo_endpoint" => "#{endpoint}/oauth/userinfo",
               "grant_types_supported" => [
                 "authorization_code",
                 "refresh_token",
                 "client_credentials",
                 "urn:ietf:params:oauth:grant-type:token-exchange"
               ],
               "code_challenge_methods_supported" => ["S256"],
               "response_types_supported" => ["code", "token"],
               "scopes_supported" => [
                 "tachyon.lobby",
                 "admin.map",
                 "admin.engine",
                 "admin.user",
                 "profile",
                 "email",
                 "groups"
               ]
             }
    end
  end
end
