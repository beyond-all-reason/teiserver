defmodule Teiserver.OAuth.GenTokenTest do
  alias Teiserver.OAuth.Tasks.GenToken
  alias Teiserver.OAuth.Token
  alias Teiserver.OAuth.TokenQueries
  alias Teiserver.OAuthFixtures
  alias Teiserver.TeiserverTestLib
  use Teiserver.DataCase, async: true

  test "no user fails" do
    assert {:error, _reason} = GenToken.create_token("oops", nil)
  end

  test "works with valid username" do
    user = TeiserverTestLib.new_user()
    OAuthFixtures.app_attrs(user.id) |> OAuthFixtures.create_app()
    assert {:ok, tok} = GenToken.create_token(user.name)
    assert %Token{} = TokenQueries.get_token(tok.value)
  end

  test "works with valid email" do
    user = TeiserverTestLib.new_user()
    OAuthFixtures.app_attrs(user.id) |> OAuthFixtures.create_app()
    assert {:ok, tok} = GenToken.create_token(user.email)
    assert %Token{} = TokenQueries.get_token(tok.value)
  end

  test "must have one oauth app in the DB" do
    user = TeiserverTestLib.new_user()
    assert {:error, _reason} = GenToken.create_token(user.email)
  end

  test "must specify an app uid if several oauth app in DB" do
    user = TeiserverTestLib.new_user()
    OAuthFixtures.app_attrs(user.id) |> OAuthFixtures.create_app()
    OAuthFixtures.app_attrs(user.id) |> Map.put(:uid, "other_uid") |> OAuthFixtures.create_app()
    assert {:error, _reason} = GenToken.create_token(user.email)
  end

  test "can select an oauth app with uid" do
    user = TeiserverTestLib.new_user()
    app = OAuthFixtures.app_attrs(user.id) |> OAuthFixtures.create_app()
    OAuthFixtures.app_attrs(user.id) |> Map.put(:uid, "other_uid") |> OAuthFixtures.create_app()
    assert {:ok, tok} = GenToken.create_token(user.email, app.uid)
    assert %Token{} = TokenQueries.get_token(tok.value)
  end
end
