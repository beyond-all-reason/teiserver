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

  defp valid_attrs(user) do
    %{
      name: "Testing app",
      uid: "test_app_uid",
      owner_id: user.id,
      scopes: ["tachyon.lobby"]
    }
  end

  test "get redirect uri" do
    user = Teiserver.TeiserverTestLib.new_user()

    {:ok, app} =
      OAuth.create_application(
        Map.put(valid_attrs(user), :redirect_uris, ["http://foo.bar/callback/path"])
      )

    assert {:ok, uri} = OAuth.get_redirect_uri(app, "http://foo.bar/callback/path?state=xyz")
    # ensure query string is preserved
    assert URI.to_string(uri) == "http://foo.bar/callback/path?state=xyz"
  end

  test "redirect uri validation" do
    user = Teiserver.TeiserverTestLib.new_user()

    {:ok, app} =
      OAuth.create_application(
        Map.put(valid_attrs(user), :redirect_uris, ["http://foo.bar/callback/path"])
      )

    # fragments aren't allowed
    assert {:error, _} = OAuth.get_redirect_uri(app, "http://foo.bar/callback/path#fragment")

    assert {:error, _} = OAuth.get_redirect_uri(app, "http://another.host/callback/path")
    assert {:error, _} = OAuth.get_redirect_uri(app, "http://foo.bar/different/path")
  end

  test "validate the various ways to handle localhost" do
    user = Teiserver.TeiserverTestLib.new_user()

    {:ok, app} =
      OAuth.create_application(
        Map.put(valid_attrs(user), :redirect_uris, ["http://localhost/callback/path"])
      )

    assert {:ok, _} = OAuth.get_redirect_uri(app, "http://localhost/callback/path")
    assert {:ok, _} = OAuth.get_redirect_uri(app, "http://localhost:7689/callback/path")
    assert {:ok, _} = OAuth.get_redirect_uri(app, "http://127.0.0.1/callback/path")
    assert {:ok, _} = OAuth.get_redirect_uri(app, "http://127.0.0.1:7689/callback/path")
    assert {:ok, _} = OAuth.get_redirect_uri(app, "http://[::1]/callback/path")
    assert {:ok, _} = OAuth.get_redirect_uri(app, "http://[::1]:7689/callback/path")
    assert {:ok, _} = OAuth.get_redirect_uri(app, "http://[0:0:0:0:0:0:0:1]/callback/path")
    assert {:ok, _} = OAuth.get_redirect_uri(app, "http://[0:0:0:0:0:0:0:1]:7689/callback/path")
  end

  test "ignore ports for localhost only" do
    user = Teiserver.TeiserverTestLib.new_user()

    uri = URI.parse("http://some.host:7890/callback/path")

    {:ok, app} =
      OAuth.create_application(Map.put(valid_attrs(user), :redirect_uris, [URI.to_string(uri)]))

    assert {:error, _} = OAuth.get_redirect_uri(app, "http://some.host:1234/callback/path")
    assert {:ok, _} = OAuth.get_redirect_uri(app, "http://some.host:7890/callback/path")
  end

  test "can validate against multiple registered uris" do
    user = Teiserver.TeiserverTestLib.new_user()

    {:ok, app} =
      OAuth.create_application(
        Map.put(valid_attrs(user), :redirect_uris, [
          "http://some.host/callback",
          "http://another.host/another/callback"
        ])
      )

    assert {:ok, _} = OAuth.get_redirect_uri(app, "http://some.host/callback")
    assert {:ok, _} = OAuth.get_redirect_uri(app, "http://another.host/another/callback")
  end
end
