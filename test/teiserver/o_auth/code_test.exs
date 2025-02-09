defmodule Teiserver.OAuth.CodeTest do
  use Teiserver.DataCase, async: true
  alias Teiserver.OAuth
  alias Teiserver.OAuthFixtures

  setup do
    user = Teiserver.TeiserverTestLib.new_user()

    {:ok, app} =
      OAuth.create_application(%{
        name: "Testing app",
        uid: "test_app_uid",
        owner_id: user.id,
        scopes: ["tachyon.lobby"],
        redirect_uris: ["http://localhost/foo"]
      })

    {:ok, user: user, app: app}
  end

  test "can get valid code", %{user: user, app: app} do
    assert {:ok, code, _} = create_code(user, app)
    assert {:ok, ^code} = OAuth.get_valid_code(code.value)
    assert {:error, :no_code} = OAuth.get_valid_code(nil)
  end

  test "cannot retrieve expired code", %{user: user, app: app} do
    yesterday = Timex.shift(Timex.now(), days: -1)
    assert {:ok, code, _} = create_code(user, app, expires_at: yesterday)
    assert {:error, :expired} = OAuth.get_valid_code(code.value)
  end

  test "cannot get code for apps with no redirect uris", %{user: user, app: app} do
    updated_app =
      OAuthFixtures.update_app(app, %{redirect_uris: []})

    attrs = create_code_attrs(user, updated_app)

    code_attrs = %{
      id: app.id,
      scopes: app.scopes,
      redirect_uri: nil,
      challenge: attrs.challenge,
      challenge_method: attrs.challenge_method
    }

    assert {:error, :invalid_flow} = OAuth.create_code(user, code_attrs)
  end

  test "can exchange valid code for token", %{user: user, app: app} do
    assert {:ok, code, attrs} = create_code(user, app)
    assert {:ok, token} = OAuth.exchange_code(code, attrs._verifier, attrs.redirect_uri)
    assert token.scopes == code.scopes
    assert token.owner_id == user.id
    # the code is now consumed and not available anymore
    assert {:error, :no_code} = OAuth.get_valid_code(code.value)
  end

  test "cannot exchange expired code for token", %{user: user, app: app} do
    yesterday = Timex.shift(Timex.now(), days: -1)
    assert {:ok, code, attrs} = create_code(user, app, expires_at: yesterday)
    assert {:error, :expired} = OAuth.exchange_code(code, attrs._verifier)
  end

  test "must use valid verifier", %{user: user, app: app} do
    assert {:ok, code, attrs} = create_code(user, app)
    attrs = Map.put(attrs, :id, app.id)
    no_match = Base.hex_encode32(:crypto.strong_rand_bytes(38), padding: false)
    assert {:error, _} = OAuth.exchange_code(code, no_match)

    no_match =
      "lollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollol"

    assert {:error, err} = OAuth.exchange_code(code, no_match, attrs.redirect_uri)
    assert err =~ "doesn't match"
  end

  test "verifier cannot be too short", %{user: user, app: app} do
    assert {:ok, _code, attrs} = create_code(user, app)
    attrs = Map.put(attrs, :id, app.id)
    verifier = "TOO_SHORT"
    challenge = OAuthFixtures.hash_verifier(verifier)
    {:ok, code} = OAuth.create_code(user, %{attrs | challenge: challenge})
    assert {:error, err} = OAuth.exchange_code(code, verifier, attrs.redirect_uri)
    assert err =~ "cannot be less than"
  end

  test "verifier cannot be too long", %{user: user, app: app} do
    assert {:ok, _code, attrs} = create_code(user, app)
    attrs = Map.put(attrs, :id, app.id)
    verifier = String.duplicate("a", 129)
    challenge = OAuthFixtures.hash_verifier(verifier)
    {:ok, code} = OAuth.create_code(user, %{attrs | challenge: challenge})
    assert {:error, err} = OAuth.exchange_code(code, verifier, attrs.redirect_uri)
    assert err =~ "cannot be more than"
  end

  test "can delete expired codes", %{user: user, app: app} do
    assert {:ok, expired_code, _} = create_code(user, app, expires_at: ~U[1980-01-01 12:23:34Z])
    assert {:ok, valid_code, _} = create_code(user, app, expires_at: ~U[2500-01-01 12:23:34Z])
    count = OAuth.delete_expired_codes()
    assert count == 1
    assert {:error, :no_code} = OAuth.get_valid_code(expired_code.value)
    assert {:ok, ^valid_code} = OAuth.get_valid_code(valid_code.value)
  end

  test "can pass custom time when deleting codes", %{user: user, app: app} do
    assert {:ok, code, _} = create_code(user, app, expires_at: ~U[2500-01-01 12:23:34Z])
    now = DateTime.add(code.expires_at, 1, :day)
    count = OAuth.delete_expired_codes(now)
    assert count == 1
    assert {:error, :no_code} = OAuth.get_valid_code(code.value)
  end

  defp create_code_attrs(user, app, opts \\ []) do
    expires_at =
      Keyword.get(opts, :expires_at, Timex.add(DateTime.utc_now(), Timex.Duration.from_days(1)))

    OAuthFixtures.code_attrs(user.id, app)
    |> Map.put(:expires_at, expires_at)
  end

  defp create_code(user, app, opts \\ []) do
    attrs = create_code_attrs(user, app, opts)

    code = OAuthFixtures.create_code(attrs)
    {:ok, code, attrs}
  end
end
