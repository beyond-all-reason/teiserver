defmodule TeiserverWeb.Admin.AutohostControllerTest do
  use TeiserverWeb.ConnCase

  alias Teiserver.Autohost

  defp setup_user(_context) do
    Central.Helpers.GeneralTestLib.conn_setup(Teiserver.TeiserverTestLib.admin_permissions())
    |> Teiserver.TeiserverTestLib.conn_setup()
  end

  defp setup_autohost(_context) do
    {:ok, autohost} = Autohost.create_autohost(%{"name" => "testing autohost"})

    %{autohost: autohost}
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
end
