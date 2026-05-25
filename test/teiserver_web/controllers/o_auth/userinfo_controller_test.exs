defmodule TeiserverWeb.OAuth.UserinfoControllerTest do
  alias Phoenix.ConnTest
  alias Teiserver.Account.Auth
  alias Teiserver.BotFixtures
  alias Teiserver.OAuth
  alias Teiserver.OAuthFixtures
  use TeiserverWeb.ConnCase

  @info_scopes ["profile", "email", "groups"]

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
    {:ok, user} = Auth.add_roles(TeiserverTestLib.new_user().id, ["Verified", "Moderator"])
    {:ok, conn: conn, user: user}
  end

  defp request_userinfo(conn, user, app, scopes) do
    token =
      OAuthFixtures.token_attrs(user, app)
      |> Map.put(:scopes, scopes)
      |> OAuthFixtures.create_token()

    conn
    |> put_req_header("authorization", "Bearer #{token.value}")
    |> get(~p"/oauth/userinfo")
    |> json_response(200)
  end

  setup [:setup_conn, :setup_app]

  test "requires a token", %{conn: conn} do
    resp = get(conn, ~p"/oauth/userinfo")
    assert resp.status == 401
  end

  test "can get user id", %{conn: conn, user: user, app: app} do
    resp = request_userinfo(conn, user, app, @info_scopes)

    assert resp["sub"] == to_string(user.id)
    assert resp["preferred_username"] == user.name
    assert resp["email"] == user.email
    assert resp["email_verified"] == true
    assert resp["groups"] == ["verified", "moderator"]
  end

  test "bot infos", %{conn: conn, app: app} do
    bot = BotFixtures.create_bot("testing_bot")
    resp = request_userinfo(conn, bot, app, @info_scopes)

    assert resp["sub"] == to_string(bot.id)
    assert resp["groups"] == []
  end

  test "username requires profile scope", %{conn: conn, user: user, app: app} do
    resp = request_userinfo(conn, user, app, Enum.reject(@info_scopes, &(&1 == "profile")))
    refute is_map_key(resp, "preferred_username")
  end

  test "bots don't have username", %{conn: conn, app: app} do
    bot = BotFixtures.create_bot("testing_bot")
    resp = request_userinfo(conn, bot, app, @info_scopes)

    refute is_map_key(resp, "preferred_username")
  end

  test "email requires email scope", %{conn: conn, user: user, app: app} do
    resp = request_userinfo(conn, user, app, Enum.reject(@info_scopes, &(&1 == "email")))
    refute is_map_key(resp, "email")
    refute is_map_key(resp, "email_verified")
  end

  test "bots don't have emails", %{conn: conn, app: app} do
    bot = BotFixtures.create_bot("testing_bot")
    resp = request_userinfo(conn, bot, app, @info_scopes)

    refute is_map_key(resp, "email")
    refute is_map_key(resp, "email_verified")
  end

  test "requires groups scope for groups", %{conn: conn, user: user, app: app} do
    resp = request_userinfo(conn, user, app, Enum.reject(@info_scopes, &(&1 == "groups")))
    refute is_map_key(resp, "groups")
  end
end
