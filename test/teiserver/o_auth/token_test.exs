defmodule Teiserver.OAuth.TokenTest do
  use Teiserver.DataCase, async: true
  alias Teiserver.OAuth

  setup do
    user = Teiserver.TeiserverTestLib.new_user()

    {:ok, app} =
      OAuth.create_application(%{
        name: "Testing app",
        uid: "test_app_uid",
        owner_id: user.id,
        scopes: ["tachyon.lobby"]
      })

    {:ok, user: user, app: app}
  end

  test "token must have an owner", %{app: app} do
    assert {:error, _} =
             Teiserver.OAuth.Token.changeset(%Teiserver.OAuth.Token{}, %{
               value: "coucou",
               application_id: app.id,
               scopes: ["tachyon.lobby"],
               expires_at: DateTime.utc_now(),
               type: :access
             })
             |> Ecto.Changeset.check_constraint(:oauth_tokens,
               name: :token_must_have_exactly_one_owner
             )
             |> Teiserver.Repo.insert()
  end

  test "can create a token directly", %{user: user, app: app} do
    assert {:ok, token} = OAuth.create_token(user, app)
    assert token.type == :access
    assert token.refresh_token.type == :refresh
    assert token.scopes == app.scopes
  end

  test "can get valid token", %{user: user, app: app} do
    assert {:ok, new_token} = OAuth.create_token(user, app)
    assert {:ok, token} = OAuth.get_valid_token(new_token.value)
    assert {:error, :no_token} = OAuth.get_valid_token(nil)
    assert token.id == new_token.id
    assert Ecto.assoc_loaded?(token.application)
  end

  test "cannot get expired token", %{user: user, app: app} do
    yesterday = Timex.shift(Timex.now(), days: -1)
    assert {:ok, token} = OAuth.create_token(user, app, now: yesterday)
    assert {:error, :expired} = OAuth.get_valid_token(token.value)
  end

  test "cannot use bearer token as refresh token", %{user: user, app: app} do
    assert {:ok, token} = OAuth.create_token(user, app)
    assert {:error, :invalid_token} = OAuth.refresh_token(token)
  end

  test "can refresh a token", %{user: user, app: app} do
    assert {:ok, token} = OAuth.create_token(user, app)
    assert {:ok, _} = OAuth.get_valid_token(token.refresh_token.value)
    assert {:ok, new_token} = OAuth.refresh_token(token.refresh_token)

    # the previous token and its refresh token should have been invalidated
    assert {:error, :no_token} = OAuth.get_valid_token(token.value)
    assert {:error, :no_token} = OAuth.get_valid_token(token.refresh_token.value)

    # the newly created token is valid
    assert {:ok, new_token_fresh} = OAuth.get_valid_token(new_token.value)
    assert new_token_fresh.id == new_token.id
  end
end
