defmodule Teiserver.OAuth.CodeTest do
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

  defp generate_challenge(method \\ :S256) do
    # A-Z,a-z,0-9 and -._~ are authorized, but can't be bothered to cover all
    # of that. hex encoding will fit
    verifier = Base.hex_encode32(:crypto.strong_rand_bytes(40), padding: false)

    challenge =
      case method do
        :plain -> verifier
        :S256 -> hash_verifier(verifier)
      end

    {verifier, challenge, method}
  end

  defp hash_verifier(verifier),
    do: Base.url_encode64(:crypto.hash(:sha256, verifier), padding: false)

  defp create_code(user, app, opts \\ []) do
    {verifier, challenge, method} = generate_challenge()

    attrs = %{
      id: app.id,
      scopes: app.scopes,
      redirect_uri: "http://some.host/a/path",
      challenge: challenge,
      challenge_method: method
    }

    {:ok, code} = OAuth.create_code(user, attrs, opts)
    {:ok, code, Map.put(attrs, :verifier, verifier)}
  end

  test "can get valid code", %{user: user, app: app} do
    assert {:ok, code, _} = create_code(user, app)
    assert {:ok, ^code} = OAuth.get_valid_code(code.value)
    assert {:error, :no_code} = OAuth.get_valid_code(nil)
  end

  test "cannot retrieve expired code", %{user: user, app: app} do
    yesterday = Timex.shift(Timex.now(), days: -1)
    assert {:ok, code, _} = create_code(user, app, now: yesterday)
    assert {:error, :expired} = OAuth.get_valid_code(code.value)
  end

  test "can exchange valid code for token", %{user: user, app: app} do
    assert {:ok, code, attrs} = create_code(user, app)
    assert {:ok, token} = OAuth.exchange_code(code, attrs.verifier, attrs.redirect_uri)
    assert token.scopes == code.scopes
    assert token.owner_id == user.id
    # the code is now consumed and not available anymore
    assert {:error, :no_code} = OAuth.get_valid_code(code.value)
  end

  test "cannot exchange expired code for token", %{user: user, app: app} do
    yesterday = Timex.shift(Timex.now(), days: -1)
    assert {:ok, code, attrs} = create_code(user, app, now: yesterday)
    assert {:error, :expired} = OAuth.exchange_code(code, attrs.verifier)
  end

  test "must use valid verifier", %{user: user, app: app} do
    assert {:ok, code, attrs} = create_code(user, app)
    no_match = Base.hex_encode32(:crypto.strong_rand_bytes(38), padding: false)
    assert {:error, _} = OAuth.exchange_code(code, no_match)

    verifier = "TOO_SHORT"
    challenge = hash_verifier(verifier)
    {:ok, code} = OAuth.create_code(user, %{attrs | challenge: challenge})
    assert {:error, _} = OAuth.exchange_code(code, verifier)

    verifier = String.duplicate("a", 129)
    challenge = hash_verifier(verifier)
    {:ok, code} = OAuth.create_code(user, %{attrs | challenge: challenge})
    assert {:error, _} = OAuth.exchange_code(code, verifier)
  end
end
