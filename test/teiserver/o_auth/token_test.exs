defmodule Teiserver.OAuth.TokenTest do
  alias Ecto.Changeset
  alias Teiserver.Account.Auth
  alias Teiserver.OAuth
  alias Teiserver.OAuth.Token
  alias Teiserver.OAuthFixtures
  alias Teiserver.Repo
  alias Teiserver.TeiserverTestLib
  use Teiserver.DataCase, async: true

  setup do
    {:ok, user} = Auth.add_roles(TeiserverTestLib.new_user().id, ["Admin"])

    {:ok, app} =
      OAuth.create_application(%{
        name: "Testing app",
        uid: "test_app_uid",
        owner_id: user.id,
        scopes: ["tachyon.lobby", "admin.map"]
      })

    {:ok, confidential_app} =
      OAuth.create_application(%{
        name: "Testing app",
        uid: "confidential_uid",
        owner_id: user.id,
        scopes: ["tachyon.lobby"],
        redirect_uris: ["http://localhost/foo"],
        confidential?: true
      })

    {:ok, user: user, app: app, confidential_app: confidential_app}
  end

  test "token must have an owner", %{app: app} do
    assert {:error, _changeset} =
             Token.changeset(%Token{}, %{
               value: "coucou",
               application_id: app.id,
               scopes: ["tachyon.lobby"],
               expires_at: DateTime.utc_now(),
               type: :access
             })
             |> Changeset.check_constraint(:oauth_tokens,
               name: :token_must_have_exactly_one_owner
             )
             |> Repo.insert()
  end

  test "can create a token directly", %{user: user, app: app} do
    assert {:ok, token} = OAuth.create_token(user, app, scopes: app.scopes)
    assert token.type == :access
    assert token.refresh_token.type == :refresh
    assert token.scopes == app.scopes
  end

  test "can create a token without refresh token", %{user: user, app: app} do
    assert {:ok, token} = OAuth.create_token(user, app, create_refresh: false, scopes: app.scopes)
    assert token.type == :access
    assert token.refresh_token == nil
  end

  test "can get valid token", %{user: user, app: app} do
    assert {:ok, new_token} = OAuth.create_token(user, app, scopes: app.scopes)
    assert {:ok, token} = OAuth.get_valid_token(new_token.value)
    assert {:error, :no_token} = OAuth.get_valid_token(nil)
    assert token.id == new_token.id
    assert Ecto.assoc_loaded?(token.application)
  end

  test "cannot get expired token", %{user: user, app: app} do
    yesterday = DateTime.shift(DateTime.utc_now(), day: -1)
    assert {:ok, token} = OAuth.create_token(user, app, now: yesterday, scopes: app.scopes)
    assert {:error, :expired} = OAuth.get_valid_token(token.value)
  end

  test "cannot use bearer token as refresh token", %{user: user, app: app} do
    assert {:ok, token} = OAuth.create_token(user, app, scopes: app.scopes)
    assert {:error, :invalid_token} = OAuth.refresh_token(token)
  end

  test "can refresh a token", %{user: user, app: app} do
    assert {:ok, token} = OAuth.create_token(user, app, scopes: app.scopes)
    assert {:ok, refresh_token} = OAuth.get_valid_token(token.refresh_token.value)
    assert {:ok, new_token} = OAuth.refresh_token(refresh_token)

    # the previous token and its refresh token should have been invalidated
    assert {:error, :no_token} = OAuth.get_valid_token(token.value)
    assert {:error, :no_token} = OAuth.get_valid_token(token.refresh_token.value)

    # the newly created token is valid
    assert {:ok, new_token_fresh} = OAuth.get_valid_token(new_token.value)
    assert new_token_fresh.id == new_token.id
  end

  test "confidential clients can get refresh tokens", %{user: user, confidential_app: app} do
    assert {:ok, token} = OAuth.create_token(user, app, scopes: app.scopes)
    assert {:ok, refresh_token} = OAuth.get_valid_token(token.refresh_token.value)

    assert {:ok, %Token{}} =
             OAuth.refresh_token(refresh_token, client_secret: app.plain_text_secret)
  end

  test "confidential clients must provide client secret", %{user: user, confidential_app: app} do
    assert {:ok, token} = OAuth.create_token(user, app, scopes: app.scopes)
    assert {:ok, refresh_token} = OAuth.get_valid_token(token.refresh_token.value)
    assert {:error, _err} = OAuth.refresh_token(refresh_token)
  end

  test "confidential clients must provide correct client secret", %{
    user: user,
    confidential_app: app
  } do
    assert {:ok, token} = OAuth.create_token(user, app, scopes: app.scopes)
    assert {:ok, refresh_token} = OAuth.get_valid_token(token.refresh_token.value)
    assert {:error, _err} = OAuth.refresh_token(refresh_token, client_secret: "nope")
  end

  test "can change scopes at refresh", %{user: user, app: app} do
    assert {:ok, token} = OAuth.create_token(user, app, scopes: app.scopes)
    assert {:ok, refresh_token} = OAuth.get_valid_token(token.refresh_token.value)
    assert {:ok, new_token} = OAuth.refresh_token(refresh_token, scopes: ["tachyon.lobby"])
    assert MapSet.new(new_token.scopes) == MapSet.new(["tachyon.lobby"])
    assert MapSet.new(token.scopes) == MapSet.new(new_token.original_scopes)
  end

  test "cannot get more scopes than originally", %{user: user, app: app} do
    assert {:ok, token} = OAuth.create_token(user, app, scopes: app.scopes)
    assert {:ok, refresh_token} = OAuth.get_valid_token(token.refresh_token.value)

    {:error, changeset} =
      OAuth.refresh_token(refresh_token, scopes: ["tachyon.lobby", "lolscope"])

    assert Keyword.has_key?(changeset.errors, :scopes)
  end

  test "cannot get scopes without correct roles", %{user: user, app: app} do
    {:ok, user} = Auth.remove_roles(user, ["Admin"])
    assert {:error, err} = OAuth.create_token(user, app, scopes: app.scopes)
    assert Keyword.has_key?(err.errors, :scopes)
  end

  test "cannot get scopes at refresh without correct roles", %{user: user, app: app} do
    {:ok, user} = Auth.remove_roles(user, ["Admin"])
    assert {:ok, token} = OAuth.create_token(user, app, scopes: ["tachyon.lobby"])
    assert {:ok, refresh_token} = OAuth.get_valid_token(token.refresh_token.value)
    assert {:error, err} = OAuth.refresh_token(refresh_token, scopes: ["admin.map"])
    assert Keyword.has_key?(err.errors, :scopes)
  end

  test "can delete expired token", %{user: user, app: app} do
    assert {:ok, token, _attr} =
             create_token(user, app,
               expires_at: ~U[2500-01-01 12:23:34Z],
               value: "far-future-token"
             )

    now = DateTime.shift(token.expires_at, day: 1)
    count = OAuth.delete_expired_tokens(now)
    assert count == 1
    assert {:error, :no_token} = OAuth.get_valid_token(token.value)
  end

  defp create_token(user, app, opts) do
    expires_at =
      Keyword.get(opts, :expires_at, DateTime.shift(DateTime.utc_now(), day: 1))

    attrs =
      Enum.into(opts, %{})
      |> Map.merge(OAuthFixtures.token_attrs(user, app))
      |> Map.put(:expires_at, expires_at)
      |> Map.put(:scopes, Keyword.get(opts, :scopes, app.scopes))

    code = OAuthFixtures.create_token(attrs)
    {:ok, code, attrs}
  end
end
