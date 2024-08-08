defmodule Teiserver.OAuth.CredentialTest do
  use Teiserver.DataCase, async: true
  alias Teiserver.{OAuth, Autohost}

  defp setup_autohost(_context) do
    {:ok, autohost} = Autohost.create_autohost(%{name: "testing_autohost"})
    %{autohost: autohost}
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

  setup [:setup_autohost, :setup_app]

  test "can create and retrieve credentials", %{app: app, autohost: autohost} do
    assert {:ok, created_cred} =
             OAuth.create_credentials(app, autohost, "some-client-id", "very-secret")

    assert {:ok, cred} = OAuth.get_valid_credentials("some-client-id", "very-secret")
    assert created_cred.id == cred.id
    assert cred.application.uid == app.uid
    # sanity check to make sure we're not storing cleartext password
    refute cred.hashed_secret =~ "very-secret"
  end

  test "can get a token from credentials", %{app: app, autohost: autohost} do
    assert {:ok, created_cred} =
             OAuth.create_credentials(app, autohost, "some-client-id", "very-secret")

    assert {:ok, token} = OAuth.get_token_from_credentials(created_cred)
    assert token.application_id == app.id
    assert token.owner_id == nil
    assert token.autohost_id == autohost.id
  end
end
