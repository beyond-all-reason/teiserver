defmodule TeiserverWeb.Admin.AssetControllerTest do
  use TeiserverWeb.ConnCase
  alias Teiserver.AssetFixtures
  alias Teiserver.Asset.EngineQueries

  defp setup_user(_context) do
    Central.Helpers.GeneralTestLib.conn_setup(Teiserver.TeiserverTestLib.admin_permissions())
    |> Teiserver.TeiserverTestLib.conn_setup()
  end

  describe "index" do
    setup [:setup_user]

    test "with no assets", %{conn: conn} do
      resp = get(conn, ~p"/teiserver/admin/asset")
      assert html_response(resp, 200) =~ "No engine"
      assert html_response(resp, 200) =~ "No game version"
    end

    test "with some engines", %{conn: conn} do
      Enum.each(1..5, fn i ->
        AssetFixtures.create_engine(%{name: "engine_#{i}"})
      end)

      resp = get(conn, ~p"/teiserver/admin/asset")

      Enum.each(1..5, fn i ->
        assert html_response(resp, 200) =~ "engine_#{i}"
      end)
    end

    test "with some game versions", %{conn: conn} do
      Enum.each(1..5, fn i ->
        AssetFixtures.create_game(%{name: "game_#{i}"})
      end)

      resp = get(conn, ~p"/teiserver/admin/asset")

      Enum.each(1..5, fn i ->
        assert html_response(resp, 200) =~ "game_#{i}"
      end)
    end
  end

  describe "engine crud" do
    setup [:setup_user]

    test "valid create", %{conn: conn} do
      resp = post(conn, ~p"/teiserver/admin/asset/engine", %{engine: %{name: "engine-name"}})
      assert redirected_to(resp) == ~p"/teiserver/admin/asset/"
      assert [engine] = EngineQueries.get_engines()
      assert engine.name == "engine-name"
    end

    test "name already taken", %{conn: conn} do
      AssetFixtures.create_engine(%{name: "engine-name"})
      resp = post(conn, ~p"/teiserver/admin/asset/engine", %{engine: %{name: "engine-name"}})
      assert html_response(resp, 400)
    end

    test "delete engine", %{conn: conn} do
      engine = AssetFixtures.create_engine(%{name: "engine-name"})
      resp = delete(conn, ~p"/teiserver/admin/asset/engine/#{engine.id}")
      assert redirected_to(resp) == ~p"/teiserver/admin/asset/"
      assert [] == EngineQueries.get_engines()
    end

    test "delete invalid engine", %{conn: conn} do
      resp = delete(conn, ~p"/teiserver/admin/asset/engine/128931")
      assert redirected_to(resp) == ~p"/teiserver/admin/asset/"
      assert %{"danger" => "engine not found"} = resp.assigns.flash
    end
  end
end
