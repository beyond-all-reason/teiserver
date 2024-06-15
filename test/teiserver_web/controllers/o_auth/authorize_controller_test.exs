defmodule TeiserverWeb.OAuth.AuthorizeControllerTest do
  use TeiserverWeb.ConnCase
  alias Central.Helpers.GeneralTestLib
  alias Teiserver.OAuth

  setup do
    {:ok, data} =
      GeneralTestLib.conn_setup(Teiserver.TeiserverTestLib.player_permissions())
      |> Teiserver.TeiserverTestLib.conn_setup()

    {:ok, app} =
      OAuth.create_application(%{
        name: "testing app",
        uid: "test_app_uid",
        owner_id: data[:user].id,
        scopes: ["tachyon.lobby"],
        redirect_uris: ["http://127.0.0.1:6789/oauth/callback"]
      })

    {:ok, Keyword.put(data, :app, app)}
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
  end
end
