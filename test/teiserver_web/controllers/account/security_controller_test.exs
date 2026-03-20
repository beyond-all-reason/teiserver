defmodule TeiserverWeb.Account.SecurityControllerTest do
  alias Central.Helpers.GeneralTestLib
  alias Teiserver.OAuth
  alias Teiserver.OAuthFixtures
  alias Phoenix.Flash
  alias Teiserver.OAuth.CodeQueries
  alias Teiserver.OAuth.TokenQueries
  alias Teiserver.TeiserverTestLib

  use TeiserverWeb.ConnCase

  test "redirected to edit password once logged in" do
    {:ok, kw} = GeneralTestLib.conn_setup([], [:no_login])
    conn = kw[:conn]
    user = kw[:user]

    conn = get(conn, ~p"/teiserver/account/security/edit_password")
    assert redirected_to(conn) == ~p"/login"
    conn = GeneralTestLib.login(conn, user.email)
    assert redirected_to(conn) == ~p"/teiserver/account/security/edit_password"
  end

  describe "OAuth application revocation" do
    setup do
      {:ok, kw} =
        GeneralTestLib.conn_setup(TeiserverTestLib.player_permissions())
        |> TeiserverTestLib.conn_setup()

      conn = kw[:conn]
      user = kw[:user]

      {:ok, app} =
        OAuth.create_application(%{
          name: "Test App",
          uid: "test_app",
          owner_id: user.id,
          scopes: ["tachyon.lobby"],
          redirect_uris: ["http://localhost/callback"]
        })

      token = OAuthFixtures.token_attrs(user.id, app) |> OAuthFixtures.create_token()
      code = OAuthFixtures.code_attrs(user.id, app) |> OAuthFixtures.create_code()

      {:ok, conn: conn, user: user, app: app, token: token, code: code}
    end

    test "successfully revokes OAuth application access", %{
      conn: conn,
      app: app,
      token: token,
      code: code
    } do
      conn = delete(conn, ~p"/teiserver/account/security/revoke_oauth/#{app.id}")
      assert redirected_to(conn) == ~p"/teiserver/account/security"

      assert Flash.get(conn.assigns.flash, :info)

      refute TokenQueries.get_token(token.value)
      refute CodeQueries.get_code(code.value)
    end

    test "handles revocation when no tokens or codes exist", %{conn: conn, user: user} do
      {:ok, app} =
        OAuth.create_application(%{
          name: "Empty App",
          uid: "empty_app",
          owner_id: user.id,
          scopes: ["tachyon.lobby"],
          redirect_uris: ["http://localhost/callback"]
        })

      conn = delete(conn, ~p"/teiserver/account/security/revoke_oauth/#{app.id}")
      assert redirected_to(conn) == ~p"/teiserver/account/security"
      assert Flash.get(conn.assigns.flash, :info)
    end
  end
end
