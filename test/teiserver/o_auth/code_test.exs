defmodule Teiserver.OAuth.CodeTest do
  alias Plug.Conn
  alias Plug.Test
  alias Teiserver.Account
  alias Teiserver.Account.Auth
  alias Teiserver.OAuth
  alias Teiserver.OAuth.Token
  alias Teiserver.OAuthFixtures
  alias Teiserver.TeiserverTestLib
  use Teiserver.DataCase, async: true

  setup do
    user = TeiserverTestLib.new_user()
    # because the o_auth logic expects a %User{} but new_user returns a
    # CacheUser, and that is getting deprecated
    user = Account.get_user!(user.id)

    {:ok, app} =
      OAuth.create_application(%{
        name: "Testing app",
        uid: "test_app_uid",
        owner_id: user.id,
        scopes: ["tachyon.lobby"],
        redirect_uris: ["http://localhost/foo"]
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

  test "challenge_method required if challenge is set", %{user: user, app: app} do
    code_attrs = %{
      application: app,
      scopes: app.scopes,
      redirect_uri: List.first(app.redirect_uris),
      challenge: "vqIld9nxOPe5uX_ndiRlwafYdt94ogYOZDlGIyj68jc"
    }

    {:error, err} = OAuth.create_code(user, code_attrs)
    assert Keyword.has_key?(err.errors, :challenge_method)
  end

  test "challenge required if challenge_method is set", %{user: user, app: app} do
    code_attrs = %{
      application: app,
      scopes: app.scopes,
      redirect_uri: List.first(app.redirect_uris),
      challenge_method: "S256"
    }

    {:error, err} = OAuth.create_code(user, code_attrs)
    assert Keyword.has_key?(err.errors, :challenge)
  end

  test "can get valid code", %{user: user, app: app} do
    assert {:ok, code, _attrs} = create_code(user, app)
    assert {:ok, ^code} = OAuth.get_valid_code(code.value)
    assert {:error, :no_code} = OAuth.get_valid_code(nil)
  end

  test "cannot retrieve expired code", %{user: user, app: app} do
    yesterday = DateTime.shift(DateTime.utc_now(), day: -1)
    assert {:ok, code, _attrs} = create_code(user, app, expires_at: yesterday)
    assert {:error, :expired} = OAuth.get_valid_code(code.value)
  end

  test "cannot get code for apps with no redirect uris", %{user: user, app: app} do
    updated_app =
      OAuthFixtures.update_app(app, %{redirect_uris: []})

    attrs = create_code_attrs(user, updated_app)

    code_attrs = %{
      application: updated_app,
      scopes: app.scopes,
      redirect_uri: nil,
      challenge: attrs.challenge,
      challenge_method: attrs.challenge_method
    }

    assert {:error, :invalid_flow} = OAuth.create_code(user, code_attrs)
  end

  test "can exchange valid code for token", %{user: user, app: app} do
    assert {:ok, code, attrs} = create_code(user, app)

    assert {:ok, token} =
             OAuth.exchange_code(code,
               verifier: attrs._verifier,
               redirect_uri: attrs.redirect_uri
             )

    assert token.scopes == code.scopes
    assert token.owner_id == user.id
    # the code is now consumed and not available anymore
    assert {:error, :no_code} = OAuth.get_valid_code(code.value)
  end

  test "pkce is required for public apps", %{user: user, app: app} do
    code_attrs = %{
      application: app,
      scopes: app.scopes,
      redirect_uri: List.first(app.redirect_uris)
    }

    {:error, err} = OAuth.create_code(user, code_attrs)
    assert Keyword.has_key?(err.errors, :challenge)
  end

  test "pkce is optional for confidential apps", %{user: user, confidential_app: app} do
    code_attrs = %{
      application: app,
      scopes: app.scopes,
      redirect_uri: List.first(app.redirect_uris)
    }

    {:ok, _code} = OAuth.create_code(user, code_attrs)
  end

  test "cannot exchange expired code for token", %{user: user, app: app} do
    yesterday = DateTime.shift(DateTime.utc_now(), day: -1)
    assert {:ok, code, attrs} = create_code(user, app, expires_at: yesterday)
    assert {:error, :expired} = OAuth.exchange_code(code, verifier: attrs._verifier)
  end

  test "must use valid verifier", %{user: user, app: app} do
    assert {:ok, code, attrs} = create_code(user, app)
    attrs = Map.put(attrs, :id, app.id)
    no_match = :crypto.strong_rand_bytes(38) |> Base.hex_encode32(padding: false)
    assert {:error, _reason} = OAuth.exchange_code(code, verifier: no_match)

    no_match =
      "lollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollollol"

    assert {:error, err} =
             OAuth.exchange_code(code, verifier: no_match, redirect_uri: attrs.redirect_uri)

    assert err =~ "doesn't match"
  end

  test "verifier cannot be too short", %{user: user, app: app} do
    assert {:ok, _code, attrs} = create_code(user, app)
    attrs = Map.put(attrs, :id, app.id)
    verifier = "TOO_SHORT"
    challenge = OAuthFixtures.hash_verifier(verifier)
    {:ok, code} = OAuth.create_code(user, %{attrs | challenge: challenge})

    assert {:error, err} =
             OAuth.exchange_code(code, verifier: verifier, redirect_uri: attrs.redirect_uri)

    assert err =~ "cannot be less than"
  end

  test "verifier cannot be too long", %{user: user, app: app} do
    assert {:ok, _code, attrs} = create_code(user, app)
    attrs = Map.put(attrs, :id, app.id)
    verifier = String.duplicate("a", 129)
    challenge = OAuthFixtures.hash_verifier(verifier)
    {:ok, code} = OAuth.create_code(user, %{attrs | challenge: challenge})

    assert {:error, err} =
             OAuth.exchange_code(code, verifier: verifier, redirect_uri: attrs.redirect_uri)

    assert err =~ "cannot be more than"
  end

  test "must pass valid challenge method", %{user: user, app: app} do
    code_attrs = %{
      application: app,
      redirect_uri: List.first(app.redirect_uris),
      scopes: app.scopes,
      challenge: OAuthFixtures.code_attrs(user, app).challenge,
      challenge_method: "lolnope that's not supported"
    }

    {:error, err} = OAuth.create_code(user, code_attrs)
    assert Keyword.has_key?(err.errors, :challenge_method)
  end

  test "confidential clients don't need pkce for tokens", %{user: user, confidential_app: app} do
    code =
      OAuthFixtures.code_attrs(user, app)
      |> Map.drop([:challenge, :challenge_method, :_verifier])
      |> OAuthFixtures.create_code()

    assert {:ok, %Token{}} =
             OAuth.exchange_code(code,
               client_secret: app.secret,
               redirect_uri: List.first(app.redirect_uris)
             )
  end

  test "confidential clients must not provide verifier when no challenge", %{
    user: user,
    confidential_app: app
  } do
    code =
      OAuthFixtures.code_attrs(user, app)
      |> Map.drop([:challenge, :challenge_method, :_verifier])
      |> OAuthFixtures.create_code()

    assert {:error, _err} =
             OAuth.exchange_code(code,
               client_secret: app.secret,
               verifier: "hello",
               redirect_uri: List.first(app.redirect_uris)
             )
  end

  test "can delete expired codes", %{user: user, app: app} do
    assert {:ok, expired_code, _expired_attrs} =
             create_code(user, app, expires_at: ~U[1980-01-01 12:23:34Z])

    assert {:ok, valid_code, _valid_attrs} =
             create_code(user, app, expires_at: ~U[2500-01-01 12:23:34Z])

    count = OAuth.delete_expired_codes()
    assert count == 1
    assert {:error, :no_code} = OAuth.get_valid_code(expired_code.value)
    assert {:ok, ^valid_code} = OAuth.get_valid_code(valid_code.value)
  end

  test "can pass custom time when deleting codes", %{user: user, app: app} do
    assert {:ok, code, _attrs} = create_code(user, app, expires_at: ~U[2500-01-01 12:23:34Z])
    now = DateTime.shift(code.expires_at, day: 1)
    count = OAuth.delete_expired_codes(now)
    assert count == 1
    assert {:error, :no_code} = OAuth.get_valid_code(code.value)
  end

  test "correct encoding of basic auth" do
    actual = OAuth.encode_basic_auth("user1", "pass1==")
    assert "Basic dXNlcjE6cGFzczElM0QlM0Q=" == actual
  end

  test "correct parsing of basic auth" do
    conn =
      Test.conn(:post, "/irrelevant")
      |> Conn.put_req_header("authorization", "Basic dXNlcjE6cGFzczElM0QlM0Q=")

    assert {"user1", "pass1=="} == OAuth.parse_basic_auth(conn)
  end

  test "correct error for garbage basic auth header" do
    conn =
      Test.conn(:post, "/irrelevant")
      |> Conn.put_req_header("authorization", "Basic dXNlcjE6cGFzczElM0QlM0")

    assert :error = OAuth.parse_basic_auth(conn)
  end

  test "check scopes against user permissions", %{user: user} do
    {:ok, admin_user} = Auth.add_roles(TeiserverTestLib.new_user().id, ["Admin"])

    {:ok, app} =
      OAuth.create_application(%{
        name: "Testing app with scopes",
        uid: "test_app_scopes_uid",
        owner_id: admin_user.id,
        scopes: ["tachyon.lobby", "admin.map"],
        redirect_uris: ["http://localhost/foo"]
      })

    attrs = OAuthFixtures.code_attrs(user, app) |> Map.merge(app)
    {:error, err} = OAuth.create_code(user, attrs)
    assert Keyword.has_key?(err.errors, :scopes)
  end

  defp create_code_attrs(user, app, opts \\ []) do
    expires_at =
      Keyword.get(opts, :expires_at, DateTime.shift(DateTime.utc_now(), day: 1))

    OAuthFixtures.code_attrs(user, app)
    |> Map.put(:expires_at, expires_at)
  end

  defp create_code(user, app, opts \\ []) do
    attrs = create_code_attrs(user, app, opts)

    code = OAuthFixtures.create_code(attrs)
    {:ok, code, attrs}
  end
end
