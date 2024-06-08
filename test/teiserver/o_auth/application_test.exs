defmodule Teiserver.OAuth.ApplicationTest do
  use Teiserver.DataCase, async: true
  alias Teiserver.OAuth

  test "reject unknown scopes at creation" do
    user = Teiserver.TeiserverTestLib.new_user()

    assert {:error, changeset} = 
             OAuth.create_application(%{
               name: "Testing app",
               uid: "test_app_uid",
               owner_id: user.id,
               scopes: ["lol"]
             })
    assert Keyword.fetch!(changeset.errors, :scopes)
  end

  test "can retrieve an app by uid" do
    user = Teiserver.TeiserverTestLib.new_user()

    assert {:ok, expected_app} =
             OAuth.create_application(%{
               name: "Testing app",
               uid: "test_app_uid",
               owner_id: user.id,
               scopes: ["tachyon.lobby"]
             })

    assert expected_app == OAuth.get_application_by_uid("test_app_uid")
  end

  test "delete app" do
    user = Teiserver.TeiserverTestLib.new_user()

    assert {:ok, expected_app} =
             OAuth.create_application(%{
               name: "Testing app",
               uid: "test_app_uid",
               owner_id: user.id,
               scopes: ["tachyon.lobby"]
             })

    assert :ok = OAuth.delete_application(expected_app)
    assert OAuth.get_application_by_uid(expected_app.uid) == nil
  end

  test "non existant uid returns nil" do
    assert OAuth.get_application_by_uid("u_wot_mate?") == nil
    assert OAuth.get_application_by_uid(nil) == nil
  end
end
