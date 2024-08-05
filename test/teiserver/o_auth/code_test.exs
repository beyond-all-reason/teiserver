defmodule Teiserver.OAuth.CodeTest do
  use Teiserver.DataCase, async: true
  alias Teiserver.OAuth
  alias Teiserver.Test.Support.OAuth, as: OAuthTest

  setup do
    user = Teiserver.TeiserverTestLib.new_user()

    {:ok, app} =
      OAuth.create_application(%{
        name: "Testing app",
        uid: "test_app_uid",
        owner_id: user.id,
        scopes: ["tachyon.lobby"],
        redirect_uri: ["http://localhost/callback"]
      })

    {:ok, user: user, app: app}
  end

  test "can get valid code", %{user: user, app: app} do
    assert {:ok, code, _} = OAuthTest.create_code(user, app)
    assert {:ok, ^code} = OAuth.get_valid_code(code.value)
    assert {:error, :no_code} = OAuth.get_valid_code(nil)
  end

  test "cannot retrieve expired code", %{user: user, app: app} do
    yesterday = Timex.shift(Timex.now(), days: -1)
    assert {:ok, code, _} = OAuthTest.create_code(user, app, now: yesterday)
    assert {:error, :expired} = OAuth.get_valid_code(code.value)
  end

  test "can exchange valid code for token", %{user: user, app: app} do
    assert {:ok, code, attrs} = OAuthTest.create_code(user, app)
    assert {:ok, token} = OAuth.exchange_code(code, attrs.verifier, attrs.redirect_uri)
    assert token.scopes == code.scopes
    assert token.owner_id == user.id
    # the code is now consumed and not available anymore
    assert {:error, :no_code} = OAuth.get_valid_code(code.value)
  end

  test "cannot exchange expired code for token", %{user: user, app: app} do
    yesterday = Timex.shift(Timex.now(), days: -1)
    assert {:ok, code, attrs} = OAuthTest.create_code(user, app, now: yesterday)
    assert {:error, :expired} = OAuth.exchange_code(code, attrs.verifier, attrs.redirect_uri)
  end

  test "must use valid verifier", %{user: user, app: app} do
    assert {:ok, code, attrs} = OAuthTest.create_code(user, app)

    no_match =
      "lollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollol"

    assert {:error, err} = OAuth.exchange_code(code, no_match, attrs.redirect_uri)
    assert err =~ "doesn't match"
  end

  test "verifier cannot be too short", %{user: user, app: app} do
    assert {:ok, _code, attrs} = OAuthTest.create_code(user, app)
    verifier = "TOO_SHORT"
    challenge = OAuthTest.hash_verifier(verifier)
    {:ok, code} = OAuth.create_code(user, %{attrs | challenge: challenge})
    assert {:error, err} = OAuth.exchange_code(code, verifier, attrs.redirect_uri)
    assert err =~ "cannot be less than"
  end

  test "verifier cannot be too long", %{user: user, app: app} do
    assert {:ok, _code, attrs} = OAuthTest.create_code(user, app)
    verifier = String.duplicate("a", 129)
    challenge = OAuthTest.hash_verifier(verifier)
    {:ok, code} = OAuth.create_code(user, %{attrs | challenge: challenge})
    assert {:error, err} = OAuth.exchange_code(code, verifier, attrs.redirect_uri)
    assert err =~ "cannot be more than"
  end
end
