defmodule Teiserver.OAuth.ApplicationTest do
  alias Teiserver.OAuth
  alias Teiserver.TeiserverTestLib
  use Teiserver.DataCase, async: true

  test "reject unknown scopes at creation" do
    user = TeiserverTestLib.new_user()

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
    user = TeiserverTestLib.new_user()

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
    user = TeiserverTestLib.new_user()

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
    user = TeiserverTestLib.new_user()

    {:ok, app} =
      valid_attrs(user)
      |> Map.put(:redirect_uris, ["http://foo.bar/callback/path"])
      |> OAuth.create_application()

    assert {:ok, uri} = OAuth.get_redirect_uri(app, "http://foo.bar/callback/path?state=xyz")
    # ensure query string is preserved
    assert URI.to_string(uri) == "http://foo.bar/callback/path?state=xyz"
  end

  test "redirect uri validation" do
    user = TeiserverTestLib.new_user()

    {:ok, app} =
      valid_attrs(user)
      |> Map.put(:redirect_uris, ["http://foo.bar/callback/path"])
      |> OAuth.create_application()

    # fragments aren't allowed
    assert {:error, _reason1} =
             OAuth.get_redirect_uri(app, "http://foo.bar/callback/path#fragment")

    assert {:error, _reason2} = OAuth.get_redirect_uri(app, "http://another.host/callback/path")
    assert {:error, _reason3} = OAuth.get_redirect_uri(app, "http://foo.bar/different/path")
  end

  test "validate the various ways to handle localhost" do
    user = TeiserverTestLib.new_user()

    {:ok, app} =
      valid_attrs(user)
      |> Map.put(:redirect_uris, ["http://localhost/callback/path"])
      |> OAuth.create_application()

    assert {:ok, _uri1} = OAuth.get_redirect_uri(app, "http://localhost/callback/path")
    assert {:ok, _uri2} = OAuth.get_redirect_uri(app, "http://localhost:7689/callback/path")
    assert {:ok, _uri3} = OAuth.get_redirect_uri(app, "http://127.0.0.1/callback/path")
    assert {:ok, _uri4} = OAuth.get_redirect_uri(app, "http://127.0.0.1:7689/callback/path")
    assert {:ok, _uri5} = OAuth.get_redirect_uri(app, "http://[::1]/callback/path")
    assert {:ok, _uri6} = OAuth.get_redirect_uri(app, "http://[::1]:7689/callback/path")
    assert {:ok, _uri7} = OAuth.get_redirect_uri(app, "http://[0:0:0:0:0:0:0:1]/callback/path")

    assert {:ok, _uri8} =
             OAuth.get_redirect_uri(app, "http://[0:0:0:0:0:0:0:1]:7689/callback/path")
  end

  test "ignore ports for localhost only" do
    user = TeiserverTestLib.new_user()

    uri = URI.parse("http://some.host:7890/callback/path")

    {:ok, app} =
      valid_attrs(user)
      |> Map.put(:redirect_uris, [uri |> URI.to_string()])
      |> OAuth.create_application()

    assert {:error, _reason} = OAuth.get_redirect_uri(app, "http://some.host:1234/callback/path")
    assert {:ok, _uri} = OAuth.get_redirect_uri(app, "http://some.host:7890/callback/path")
  end

  test "can validate against multiple registered uris" do
    user = TeiserverTestLib.new_user()

    {:ok, app} =
      valid_attrs(user)
      |> Map.put(:redirect_uris, [
        "http://some.host/callback",
        "http://another.host/another/callback"
      ])
      |> OAuth.create_application()

    assert {:ok, _uri1} = OAuth.get_redirect_uri(app, "http://some.host/callback")
    assert {:ok, _uri2} = OAuth.get_redirect_uri(app, "http://another.host/another/callback")
  end
end
