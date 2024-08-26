defmodule TeiserverWeb.Admin.AutohostControllerTest do
  use TeiserverWeb.ConnCase, async: true

  alias Teiserver.{Autohost, OAuth}
  alias Teiserver.OAuth.CredentialQueries
  alias Teiserver.{OAuthFixtures, AutohostFixtures}

  defp setup_user(_context) do
    Central.Helpers.GeneralTestLib.conn_setup(Teiserver.TeiserverTestLib.admin_permissions())
    |> Teiserver.TeiserverTestLib.conn_setup()
  end

  defp setup_autohost(_context) do
    {:ok, autohost} = Autohost.create_autohost(%{"name" => "testing autohost"})

    %{autohost: autohost}
  end

  defp setup_app(context) do
    owner_id = context[:user].id
    app = OAuthFixtures.app_attrs(owner_id) |> OAuthFixtures.create_app()

    %{app: app}
  end

  describe "index" do
    setup [:setup_user]

    test "with no autohost", %{conn: conn} do
      resp = get(conn, ~p"/teiserver/admin/autohost")
      assert html_response(resp, 200) =~ "No autohost"
    end

    test "with some autohosts", %{conn: conn} do
      Enum.each(1..5, fn i ->
        {:ok, _app} = Autohost.create_autohost(%{name: "autohost_#{i}"})
      end)

      resp = get(conn, ~p"/teiserver/admin/autohost")

      Enum.each(1..5, fn i ->
        assert html_response(resp, 200) =~ "autohost_#{i}"
      end)
    end
  end

  describe "create" do
    setup [:setup_user]

    test "with valid data", %{conn: conn} do
      data = %{"name" => "autohost fixture"}
      conn = post(conn, ~p"/teiserver/admin/autohost", autohost: data)
      assert %{id: id} = redirected_params(conn)
      conn = get(conn, ~p"/teiserver/admin/autohost/#{id}")
      assert html_response(conn, 200) =~ "autohost fixture"
    end

    test "with missing name", %{conn: conn} do
      data = %{}
      conn = post(conn, ~p"/teiserver/admin/autohost", autohost: data)
      assert conn.status == 400
    end

    test "with name too short", %{conn: conn} do
      data = %{"name" => "a"}
      conn = post(conn, ~p"/teiserver/admin/autohost", autohost: data)
      assert conn.status == 400
    end

    test "with name too long", %{conn: conn} do
      data = %{"name" => "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}
      conn = post(conn, ~p"/teiserver/admin/autohost", autohost: data)
      assert conn.status == 400
    end
  end

  describe "show" do
    setup [:setup_user, :setup_autohost]

    test "404 for unknown autohost", %{conn: conn} do
      resp = post(conn, ~p"/teiserver/admin/autohost/lolnope")
      assert resp.status == 404
    end

    test "can get data for given autohost", %{conn: conn, autohost: autohost} do
      conn = get(conn, ~p"/teiserver/admin/autohost/#{autohost.id}")
      assert html_response(conn, 200) =~ autohost.name
    end
  end

  describe "edit" do
    setup [:setup_user, :setup_autohost]

    test "change name", %{conn: conn, autohost: autohost} do
      data = %{"name" => "another name"}
      conn = patch(conn, ~p"/teiserver/admin/autohost/#{autohost.id}", autohost: data)

      assert conn.status == 200

      assert %Autohost.Autohost{
               name: "another name"
             } = Autohost.get_by_id(autohost.id)
    end

    test "invalid name", %{conn: conn, autohost: autohost} do
      data = %{"name" => "a"}
      conn = patch(conn, ~p"/teiserver/admin/autohost/#{autohost.id}", autohost: data)

      assert conn.status == 400

      assert autohost == Autohost.get_by_id(autohost.id)
    end
  end

  describe "credentials" do
    setup [:setup_user, :setup_autohost, :setup_app]

    test "create", %{conn: conn, autohost: autohost, app: app} do
      conn =
        post(conn, ~p"/teiserver/admin/autohost/#{autohost.id}/credential", application: app.id)

      assert %{id: id} = redirected_params(conn)

      secret = conn.cookies["client_secret"]
      assert [cred] = CredentialQueries.for_autohost(autohost)
      assert Argon2.verify_pass(secret, cred.hashed_secret)

      conn = get(conn, ~p"/teiserver/admin/autohost/#{id}")

      # secret only shown once
      assert is_nil(conn.cookies["client_secret"])
    end

    test "with invalid app", %{conn: conn, autohost: autohost} do
      conn =
        post(conn, ~p"/teiserver/admin/autohost/#{autohost.id}/credential", application: -1234)

      assert conn.status == 404
    end

    test "delete", %{conn: conn, autohost: autohost, app: app} do
      {:ok, cred} = OAuth.create_credentials(app.id, autohost.id, "client_id", "verysecret")
      conn = delete(conn, ~p"/teiserver/admin/autohost/#{autohost.id}/credential/#{cred.id}")
      assert conn.status == 302

      assert {:error, _} = OAuth.get_valid_credentials("client_id", "verysecret")
    end

    test "delete invalid id", %{conn: conn, autohost: autohost, app: app} do
      other_autohost = AutohostFixtures.create_autohost("other autohost name")

      {:ok, _cred} =
        OAuth.create_credentials(app.id, other_autohost.id, "client_id", "verysecret")

      assert {:ok, cred} = OAuth.get_valid_credentials("client_id", "verysecret")

      conn = delete(conn, ~p"/teiserver/admin/autohost/#{autohost.id}/credential/#{cred.id}")
      assert conn.status == 400

      # cred is still here
      assert {:ok, cred} = OAuth.get_valid_credentials("client_id", "verysecret")
      refute is_nil(cred)
    end
  end
end
