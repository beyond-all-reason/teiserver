defmodule TeiserverWeb.Account.SecurityControllerTest do
  alias Phoenix.Flash
  alias Teiserver.Account
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.Logging.LoggingTestLib
  alias Teiserver.OAuth
  alias Teiserver.OAuth.CodeQueries
  alias Teiserver.OAuth.TokenQueries
  alias Teiserver.OAuthFixtures
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

      token = OAuthFixtures.token_attrs(user, app) |> OAuthFixtures.create_token()
      code = OAuthFixtures.code_attrs(user, app) |> OAuthFixtures.create_code()

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

  describe "Discord account linking" do
    setup do
      {:ok, kw} =
        GeneralTestLib.conn_setup(TeiserverTestLib.player_permissions())
        |> TeiserverTestLib.conn_setup()

      {:ok, conn: kw[:conn], user: kw[:user]}
    end

    test "generating a discord link code", %{
      conn: conn,
      user: user
    } do
      conn = post(conn, ~p"/teiserver/account/security/discord/generate_code")
      assert redirected_to(conn) == ~p"/teiserver/account/security"

      [code] =
        Account.list_codes(search: [user_id: user.id, purpose: "discord_link", expired: false])

      assert code.user_id == user.id

      # Attempting to generate a new code while
      # an unexpired one exists already will not create a new one
      conn = post(conn, ~p"/teiserver/account/security/discord/generate_code")
      assert redirected_to(conn) == ~p"/teiserver/account/security"

      [^code] =
        Account.list_codes(search: [user_id: user.id, purpose: "discord_link", expired: false])
    end

    test "unlinking", %{conn: conn, user: user} do
      discord_id = 123_456_789
      {:ok, user} = Account.update_user_discord_id(user, %{discord_id: discord_id})

      conn = delete(conn, ~p"/teiserver/account/security/discord/unlink")
      assert redirected_to(conn) == ~p"/teiserver/account/security"

      updated_user = Account.get_user!(user.id)
      assert updated_user.discord_id == nil
      assert Account.get_userid_by_discord_id(discord_id) == nil

      log = LoggingTestLib.get_most_recent_audit_log_for_user(user.id)
      assert log.action == "Discord.unlink"
    end
  end
end
