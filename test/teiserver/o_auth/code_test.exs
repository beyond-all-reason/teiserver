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
    assert {:ok, code} = OAuth.create_code(user, app, now: yesterday)
    assert {:error, :expired} = OAuth.get_valid_code(code.value)
  end
end
