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

  test "can get valid code", %{user: user, app: app} do
    assert {:ok, code} = OAuth.create_code(user, app)
    assert {:ok, ^code} = OAuth.get_valid_code(code.value)
    assert {:error, :no_code} = OAuth.get_valid_code(nil)
  end

  test "cannot retrieve expired code", %{user: user, app: app} do
    yesterday = Timex.shift(Timex.now(), days: -1)
    assert {:ok, code} = OAuth.create_code(user, app, %{}, now: yesterday)
    assert {:error, :expired} = OAuth.get_valid_code(code.value)
  end

  test "can exchange valid code for token", %{user: user, app: app} do
    assert {:ok, code} = OAuth.create_code(user, app)
    assert {:ok, token} = OAuth.exchange_code(code)
    assert token.scopes == code.scopes
    assert token.owner_id == user.id
    # the code is now consumed and not available anymore
    assert {:error, :no_code} = OAuth.get_valid_code(code.value)
  end

  test "redirect uri must be provided and match", %{user: user, app: app} do
    assert {:ok, code} = OAuth.create_code(user, app, %{redirect_uri: "http://127.0.0.1/foo"})
    assert {:error, :redirect_uri_mismatch} = OAuth.exchange_code(code)
    assert {:error, :redirect_uri_mismatch} = OAuth.exchange_code(code, "http://another.url/")
  end

  test "cannot exchange expired code for token", %{user: user, app: app} do
    yesterday = Timex.shift(Timex.now(), days: -1)
    assert {:ok, code} = OAuth.create_code(user, app, %{}, now: yesterday)
    assert {:error, :expired} = OAuth.exchange_code(code)
  end
end
