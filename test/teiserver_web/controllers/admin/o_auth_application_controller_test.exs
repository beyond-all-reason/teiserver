defmodule TeiserverWeb.Admin.OAuthApplicationControllerTest do
  alias Teiserver.Account.Auth
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.OAuth
  alias Teiserver.OAuth.Application
  alias Teiserver.OAuthFixtures
  alias Teiserver.TeiserverTestLib

  use TeiserverWeb.ConnCase

  defp setup_user(_context) do
    {:ok, ctx} =
      GeneralTestLib.conn_setup(TeiserverTestLib.admin_permissions())
      |> TeiserverTestLib.conn_setup()

    Auth.add_roles(ctx[:user], ["Admin"])
    {:ok, ctx}
  end

  defp setup_app(context) do
    {:ok, app} =
      OAuth.create_application(%{
        name: "generic name",
        uid: "generic_name",
        scopes: ["tachyon.lobby"],
        description: "fixture oauth app",
        owner_id: context.user.id
      })

    %{app: app}
  end

  describe "index" do
    setup [:setup_user]

    test "with no application", %{conn: conn} do
      resp = get(conn, ~p"/teiserver/admin/oauth_application")
      assert html_response(resp, 200) =~ "No application"
    end

    test "with some applications", %{conn: conn, user: user} do
      Enum.each(1..5, fn i ->
        {:ok, _app} =
          OAuth.create_application(%{
            name: "generic name #{i}",
            uid: "generic_name_#{i}",
            scopes: ["tachyon.lobby"],
            description: "fixture oauth app #{i}",
            owner_id: user.id
          })
      end)

      resp = get(conn, ~p"/teiserver/admin/oauth_application")

      Enum.each(1..5, fn i ->
        assert html_response(resp, 200) =~ "generic_name_#{i}"
      end)
    end
  end

  describe "create" do
    setup [:setup_user]

    test "with valid data", %{conn: conn, user: user} do
      data = valid_app_attr(user)
      conn = post(conn, ~p"/teiserver/admin/oauth_application", data)
      assert %{id: id} = redirected_params(conn)
      conn = get(conn, ~p"/teiserver/admin/oauth_application/#{id}")
      assert html_response(conn, 200) =~ "generic name"
      db_app_id = OAuth.get_application_by_uid(data["application"]["uid"]).id
      assert id == to_string(db_app_id)
    end

    test "confidential client has secret", %{conn: conn, user: user} do
      data = valid_app_attr(user) |> put_in(["application", "confidential?"], true)
      conn = post(conn, ~p"/teiserver/admin/oauth_application", data)
      assert %{id: id} = redirected_params(conn)
      conn = get(conn, ~p"/teiserver/admin/oauth_application/#{id}")
      resp = assert html_response(conn, 200)
      assert resp =~ "generic name"
      db_app = OAuth.get_application_by_uid(data["application"]["uid"])
      assert is_binary(db_app.secret)
      {:ok, parsed} = Floki.parse_document(resp)
      element = Floki.find(parsed, "#plain_client_secret")
      secret = Floki.text(element)
      assert Argon2.verify_pass(secret, db_app.secret)
    end

    test "must provide email of valid user", %{conn: conn, user: user} do
      data = valid_app_attr(user) |> put_in(["application", "owner_email"], "lol@nope.com")
      resp = post(conn, ~p"/teiserver/admin/oauth_application", data)
      assert resp.status == 400
    end
  end

  describe "show" do
    setup [:setup_user, :setup_app]

    test "404 for unknown app", %{conn: conn} do
      resp = get(conn, ~p"/teiserver/admin/oauth_application/lolnope")
      assert resp.status == 404
    end

    test "can get data for a given app", %{conn: conn, app: app} do
      conn = get(conn, ~p"/teiserver/admin/oauth_application/#{app.id}")
      assert html_response(conn, 200) =~ app.name
    end
  end

  describe "edit" do
    setup [:setup_user, :setup_app]

    test "valid attributes", %{conn: conn, app: app} do
      data = %{
        "description" => "updated description",
        "redirect_uris" => "http://localhost/foo, http://localhost/bar"
      }

      conn =
        patch(conn, ~p"/teiserver/admin/oauth_application/#{app.id}",
          application: data,
          scopes: %{}
        )

      assert conn.status == 200

      assert %Application{
               description: "updated description",
               redirect_uris: ["http://localhost/foo", "http://localhost/bar"]
             } = OAuth.get_application_by_uid(app.uid)
    end

    test "can update scopes", %{conn: conn, app: app} do
      scopes = %{"admin.engine" => "true"}

      conn = patch(conn, ~p"/teiserver/admin/oauth_application/#{app.id}", scopes: scopes)

      assert conn.status == 200

      assert %Application{scopes: ["admin.engine"]} = OAuth.get_application_by_uid(app.uid)
    end

    test "reject invalid redirect uris", %{conn: conn, app: app} do
      data = %{"redirect_uris" => "http://localhost/foo, lolnope"}
      conn = patch(conn, ~p"/teiserver/admin/oauth_application/#{app.id}", application: data)
      assert conn.status == 400
    end

    test "ignores invalid scopes", %{conn: conn, app: app} do
      scopes = %{"not.a.valid.scope" => "true"}

      conn = patch(conn, ~p"/teiserver/admin/oauth_application/#{app.id}", scopes: scopes)

      assert conn.status == 200
      assert %Application{} = updated_app = OAuth.get_application_by_uid(app.uid)
      assert updated_app.scopes == app.scopes
    end

    test "doesn't update secret when already set", %{conn: conn} = ctx do
      app =
        OAuthFixtures.app_attrs(ctx[:user].id)
        |> Map.put(:confidential?, true)
        |> OAuthFixtures.create_app()

      data = %{"confidential?" => "true"}

      conn = patch(conn, ~p"/teiserver/admin/oauth_application/#{app.id}", application: data)
      assert conn.status == 200
      assert %Application{} = updated_app = OAuth.get_application_by_uid(app.uid)
      assert updated_app.secret == app.secret
    end

    test "doesn't update secret if `confidential?` isn't provided", %{conn: conn} = ctx do
      app =
        OAuthFixtures.app_attrs(ctx[:user].id)
        |> Map.put(:confidential?, true)
        |> OAuthFixtures.create_app()

      data = %{}

      conn = patch(conn, ~p"/teiserver/admin/oauth_application/#{app.id}", application: data)
      assert conn.status == 200
      assert %Application{} = updated_app = OAuth.get_application_by_uid(app.uid)
      assert updated_app.secret == app.secret
    end

    test "delete secret when confidential? is unchecked", %{conn: conn} = ctx do
      app =
        OAuthFixtures.app_attrs(ctx[:user].id)
        |> Map.put(:confidential?, true)
        |> OAuthFixtures.create_app()

      data = %{"confidential?" => "false"}

      conn = patch(conn, ~p"/teiserver/admin/oauth_application/#{app.id}", application: data)
      assert conn.status == 200
      assert %Application{} = updated_app = OAuth.get_application_by_uid(app.uid)
      assert updated_app.secret == nil
    end
  end

  defp valid_app_attr(user) do
    %{
      "application" => %{
        "name" => "generic name",
        "uid" => "generic_name",
        "description" => "test app",
        "owner_email" => user.email
      },
      "scopes" => %{"tachyon.lobby" => "true"}
    }
  end
end
