defmodule Teiserver.OAuth.GenTokenTest do
  use Teiserver.DataCase, async: true
  alias Teiserver.OAuthFixtures
  alias Teiserver.OAuth.Tasks.GenToken
  alias Teiserver.OAuth.{Token, TokenQueries}

  test "no user fails" do
    assert {:error, _} = GenToken.create_token("oops", nil)
  end

  test "works with valid username" do
    user = Teiserver.TeiserverTestLib.new_user()
    OAuthFixtures.app_attrs(user.id) |> OAuthFixtures.create_app()
    assert {:ok, tok} = GenToken.create_token(user.name)
    assert %Token{} = TokenQueries.get_token(tok.value)
  end

  test "works with valid email" do
    user = Teiserver.TeiserverTestLib.new_user()
    OAuthFixtures.app_attrs(user.id) |> OAuthFixtures.create_app()
    assert {:ok, tok} = GenToken.create_token(user.email)
    assert %Token{} = TokenQueries.get_token(tok.value)
  end

  test "must have one oauth app in the DB" do
    user = Teiserver.TeiserverTestLib.new_user()
    assert {:error, _} = GenToken.create_token(user.email)
  end

  test "must specify an app uid if several oauth app in DB" do
    user = Teiserver.TeiserverTestLib.new_user()
    OAuthFixtures.app_attrs(user.id) |> OAuthFixtures.create_app()
    OAuthFixtures.app_attrs(user.id) |> Map.put(:uid, "other_uid") |> OAuthFixtures.create_app()
    assert {:error, _} = GenToken.create_token(user.email)
  end

  test "can select an oauth app with uid" do
    user = Teiserver.TeiserverTestLib.new_user()
    app = OAuthFixtures.app_attrs(user.id) |> OAuthFixtures.create_app()
    OAuthFixtures.app_attrs(user.id) |> Map.put(:uid, "other_uid") |> OAuthFixtures.create_app()
    assert {:ok, tok} = GenToken.create_token(user.email, app.uid)
    assert %Token{} = TokenQueries.get_token(tok.value)
  end
end
