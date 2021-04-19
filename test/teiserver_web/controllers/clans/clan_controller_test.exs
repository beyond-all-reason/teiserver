defmodule TeiserverWeb.Clans.ClanControllerTest do
  use CentralWeb.ConnCase

  # alias Teiserver.Clan
  # alias Teiserver.ClanTestLib

  alias Central.Helpers.GeneralTestLib
  setup do
    GeneralTestLib.conn_setup(Teiserver.TestLib.player_permissions())
    |> Teiserver.TestLib.conn_setup
  end

  describe "index" do
    test "lists all clans", %{conn: conn} do
      conn = get(conn, Routes.ts_clans_clan_path(conn, :index))
      assert html_response(conn, 200) =~ "Clans"
    end
  end

  # describe "show clan" do
  #   test "renders show page", %{conn: conn} do
  #     clan = ClanTestLib.clan_fixture()
  #     resp = get(conn, Routes.clans_clan_path(conn, :show, clan))
  #     assert html_response(resp, 200) =~ "Edit clan"
  #   end

  #   test "renders show nil item", %{conn: conn} do
  #     assert_error_sent 404, fn ->
  #       get(conn, Routes.clans_clan_path(conn, :show, -1))
  #     end
  #   end
  # end
end
