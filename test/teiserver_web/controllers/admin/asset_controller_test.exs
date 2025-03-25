defmodule TeiserverWeb.Admin.AssetControllerTest do
  use TeiserverWeb.ConnCase
  alias Teiserver.AssetFixtures

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
end
