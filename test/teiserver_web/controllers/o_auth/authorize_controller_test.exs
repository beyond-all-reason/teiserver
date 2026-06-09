defmodule TeiserverWeb.OAuth.AuthorizeControllerTest do
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.OAuth
  alias Teiserver.OAuthFixtures
  alias Teiserver.TeiserverTestLib
  use TeiserverWeb.ConnCase

  setup do
    {:ok, data} =
      GeneralTestLib.conn_setup(TeiserverTestLib.player_permissions())
      |> TeiserverTestLib.conn_setup()

    {:ok, app} =
      OAuth.create_application(%{
        name: "testing app",
        uid: "test_app_uid",
        owner_id: data[:user].id,
        scopes: ["tachyon.lobby"],
        redirect_uris: ["http://127.0.0.1:6789/oauth/callback"]
      })

    data =
      data
      |> Keyword.put(:app, app)
      |> Keyword.put(:owner, data[:user])

    {:ok, data}
  end

  describe "authorize" do
    test "must provide client_id", %{conn: conn} do
      assert get(conn, ~p"/oauth/authorize").status == 400
    end

    test "must provide valid client_id", %{conn: conn} do
      assert get(conn, ~p"/oauth/authorize?client_id=random_client").status == 400
    end

    test "get auth screen with valid client_id", %{conn: conn, app: app} do
      redir_uri = "http://127.0.0.1/oauth/callback"
      query = %{client_id: app.uid, redirect_uri: redir_uri}
      resp = get(conn, ~p"/oauth/authorize?#{query}")
      assert html_response(resp, 200) =~ app.name
    end

    test "can request scopes", %{conn: conn, owner: owner} do
      {:ok, app} =
        OAuth.create_application(%{
          name: "testing app",
          uid: "test_app_scopes",
          owner_id: owner.id,
          scopes: ["profile", "email", "groups"],
          redirect_uris: ["http://127.0.0.1:6789/oauth/callback"]
        })

      redir_uri = "http://127.0.0.1/oauth/callback"
      query = %{client_id: app.uid, redirect_uri: redir_uri, scope: "profile groups"}
      resp = get(conn, ~p"/oauth/authorize?#{query}")
      html_resp = assert html_response(resp, 200)
      assert html_resp =~ app.name
      {:ok, parsed} = Floki.parse_document(html_resp)
      scope_element = Floki.find(parsed, "input[type=hidden][name=scope]")
      assert Floki.attribute(scope_element, "value") == ["profile groups"]
    end

    test "must request scopes from the app", %{conn: conn, app: app} do
      redir_uri = "http://127.0.0.1/oauth/callback"
      query = %{client_id: app.uid, redirect_uri: redir_uri, scope: "tachyon.lobby profile"}
      resp = get(conn, ~p"/oauth/authorize?#{query}")
      assert resp.status == 400
    end

    test "automatically get code when app already authorized", %{
      conn: conn,
      app: app,
      owner: owner
    } do
      # because we consider an app to be authorized when there is at least one code/token
      # that'll likely change as it's not a great modelling.
      OAuthFixtures.token_attrs(owner, app) |> OAuthFixtures.create_token()

      redir_uri = "http://127.0.0.1/oauth/callback"

      query = %{
        client_id: app.uid,
        redirect_uri: redir_uri,
        code_challenge: "blah",
        code_challenge_method: "S256",
        state: "some random state"
      }

      resp = get(conn, ~p"/oauth/authorize?#{query}")
      assert redired = redirected_to(resp, 302)
      parsed = URI.parse(redired).query |> URI.decode_query()
      {:ok, %OAuth.Code{}} = OAuth.get_valid_code(parsed["code"])
    end

    test "automatically get code when app already authorized (confidential client)", %{
      conn: conn,
      owner: owner
    } do
      {:ok, app} =
        OAuth.create_application(%{
          name: "testing app",
          uid: "test_app_scopes",
          owner_id: owner.id,
          scopes: ["profile", "email", "groups"],
          redirect_uris: ["http://127.0.0.1:6789/oauth/callback"],
          confidential?: true
        })

      # because we consider an app to be authorized when there is at least one code/token
      # that'll likely change as it's not a great modelling.
      OAuthFixtures.token_attrs(owner, app) |> OAuthFixtures.create_token()

      redir_uri = "http://127.0.0.1/oauth/callback"

      query = %{
        client_id: app.uid,
        redirect_uri: redir_uri,
        state: "some random state"
        # no code challenge
      }

      resp = get(conn, ~p"/oauth/authorize?#{query}")
      assert redired = redirected_to(resp, 302)
      parsed = URI.parse(redired).query |> URI.decode_query()
      {:ok, %OAuth.Code{}} = OAuth.get_valid_code(parsed["code"])
    end

    test "authorized public client still must pass a code challenge", %{
      conn: conn,
      app: app,
      owner: owner
    } do
      # because we consider an app to be authorized when there is at least one code/token
      # that'll likely change as it's not a great modelling.
      OAuthFixtures.token_attrs(owner, app) |> OAuthFixtures.create_token()

      redir_uri = "http://127.0.0.1/oauth/callback"

      query = %{
        client_id: app.uid,
        redirect_uri: redir_uri,
        state: "some random state"
      }

      resp = get(conn, ~p"/oauth/authorize?#{query}")
      assert resp.status == 400
    end
  end

  describe "generate code" do
    test "get redirected with a code", %{conn: conn, app: app} do
      data = %{
        client_id: app.uid,
        response_type: "code",
        code_challenge: "blah",
        code_challenge_method: "S256",
        redirect_uri: hd(app.redirect_uris),
        state: "some random state"
      }

      resp = post(conn, ~p"/oauth/authorize", data)

      assert redired = redirected_to(resp, 302)
      parsed = URI.parse(redired)

      assert URI.to_string(%{parsed | query: nil}) == hd(app.redirect_uris)
      query = URI.decode_query(parsed.query)
      assert query["code"] != nil
      assert query["state"] == data[:state]
      {:ok, code} = OAuth.get_valid_code(query["code"])
      assert code.redirect_uri == data.redirect_uri
    end

    test "only include state in redirection if provided", %{conn: conn, app: app} do
      data = %{
        client_id: app.uid,
        response_type: "code",
        code_challenge: "blah",
        code_challenge_method: "S256",
        state: "",
        redirect_uri: hd(app.redirect_uris)
        # no state
      }

      resp = post(conn, ~p"/oauth/authorize", data)

      assert redired = redirected_to(resp, 302)
      parsed = URI.parse(redired)
      query = URI.decode_query(parsed.query)
      refute Map.has_key?(query, "state")
    end

    test "must provide client_id and redirect_uri", %{conn: conn, app: app} do
      data = %{
        client_id: app.uid,
        response_type: "code",
        code_challenge: "blah",
        code_challenge_method: "S256",
        redirect_uri: hd(app.redirect_uris),
        state: "some random state"
      }

      resp = post(conn, ~p"/oauth/authorize", Map.drop(data, [:client_id]))
      assert html_response(resp, 400) =~ "missing client_id"

      resp = post(conn, ~p"/oauth/authorize", Map.drop(data, [:redirect_uri]))
      assert html_response(resp, 400) =~ "missing redirect_uri"

      resp = post(conn, ~p"/oauth/authorize", Map.drop(data, [:redirect_uri, :client_id]))
      assert resp.status == 400

      resp = post(conn, ~p"/oauth/authorize", %{data | client_id: "lolnope"})
      assert html_response(resp, 400) =~ "invalid client_id"
    end

    test "invalid request when incorrect challenge method", %{conn: conn, app: app} do
      data = %{
        client_id: app.uid,
        response_type: "code",
        code_challenge: "blah",
        code_challenge_method: "this is not valid",
        redirect_uri: hd(app.redirect_uris),
        state: "some random state"
      }

      resp = post(conn, ~p"/oauth/authorize", data)
      assert html_response(resp, 400) =~ "Bad request"
    end

    test "redirected for invalid response type", %{conn: conn, app: app} do
      data = %{
        client_id: app.uid,
        response_type: "lolnope",
        code_challenge: "blah",
        code_challenge_method: "S256",
        redirect_uri: hd(app.redirect_uris),
        state: "some random state"
      }

      resp = post(conn, ~p"/oauth/authorize", data)
      assert redired = redirected_to(resp, 302)
      parsed = URI.parse(redired).query
      assert String.starts_with?(redired, data.redirect_uri)

      assert %{"error" => "unsupported_response_type", "state" => "some random state"} =
               URI.decode_query(parsed)
    end

    test "code scopes based on request not app", %{conn: conn, owner: owner} do
      {:ok, app} =
        OAuth.create_application(%{
          name: "testing app",
          uid: "test_app_scopes",
          owner_id: owner.id,
          scopes: ["profile", "email", "groups"],
          redirect_uris: ["http://127.0.0.1:6789/oauth/callback"]
        })

      data = %{
        client_id: app.uid,
        response_type: "code",
        code_challenge: "blah",
        code_challenge_method: "S256",
        redirect_uri: hd(app.redirect_uris),
        state: "some random state",
        scope: "profile groups"
      }

      resp = post(conn, ~p"/oauth/authorize", data)
      assert redired = redirected_to(resp, 302)
      parsed = URI.parse(redired).query |> URI.decode_query()

      assert parsed["scope"] == "profile groups"
      {:ok, %OAuth.Code{} = db_code} = OAuth.get_valid_code(parsed["code"])
      assert Enum.sort(db_code.scopes) == ["groups", "profile"]
    end

    test "request scopes must be subset of app scopes", %{conn: conn, app: app} do
      data = %{
        client_id: app.uid,
        response_type: "code",
        code_challenge: "blah",
        code_challenge_method: "S256",
        redirect_uri: hd(app.redirect_uris),
        state: "some random state",
        scope: "profile"
      }

      resp = post(conn, ~p"/oauth/authorize", data)
      assert redired = redirected_to(resp, 302)
      parsed = URI.parse(redired).query |> URI.decode_query()
      assert %{"error" => "invalid_request"} = parsed
    end
  end
end
