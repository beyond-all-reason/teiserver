defmodule Teiserver.OAuth.CredentialTest do
  use Teiserver.DataCase, async: true
  alias Teiserver.{OAuth, Bot}
  alias Teiserver.OAuthFixtures

  defp setup_bot(_context) do
    {:ok, bot} = Bot.create_bot(%{name: "testing_bot"})
    %{bot: bot}
  end

  defp setup_app(_context) do
    user = Teiserver.TeiserverTestLib.new_user()

    {:ok, app} =
      OAuth.create_application(%{
        name: "Testing app",
        uid: "test_app_uid",
        owner_id: user.id,
        scopes: ["tachyon.lobby"]
      })

    %{user: user, app: app}
  end

  setup [:setup_bot, :setup_app]

  test "can create and retrieve credentials", %{app: app, bot: bot} do
    assert {:ok, created_cred} =
             OAuth.create_credentials(app, bot, "some-client-id", "very-secret")

    assert {:ok, cred} = OAuth.get_valid_credentials("some-client-id", "very-secret")
    assert created_cred.id == cred.id
    assert cred.application.uid == app.uid
    # sanity check to make sure we're not storing cleartext password
    refute cred.hashed_secret =~ "very-secret"
  end

  test "can get a token from credentials", %{app: app, bot: bot} do
    assert {:ok, created_cred} =
             OAuth.create_credentials(app, bot, "some-client-id", "very-secret")

    assert {:ok, token} = OAuth.get_token_from_credentials(created_cred, app.scopes)
    assert token.application_id == app.id
    assert token.owner_id == nil
    assert token.bot_id == bot.id
  end

  test "must provide scopes", %{app: app, bot: bot} do
    OAuthFixtures.update_app(app, %{scopes: ["tachyon.lobby", "admin.engine"]})

    assert {:ok, created_cred} =
             OAuth.create_credentials(app, bot, "some-client-id", "very-secret")

    assert {:error, :invalid_scope} =
             OAuth.get_token_from_credentials(created_cred, [])
  end

  test "must provide valid scopes", %{app: app, bot: bot} do
    OAuthFixtures.update_app(app, %{scopes: ["tachyon.lobby", "admin.engine"]})

    assert {:ok, created_cred} =
             OAuth.create_credentials(app, bot, "some-client-id", "very-secret")

    assert {:error, :invalid_scope} =
             OAuth.get_token_from_credentials(created_cred, ["admin.map"])
  end
end
