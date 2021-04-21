defmodule TeiserverWeb.Clans.ClanControllerTest do
  use CentralWeb.ConnCase

  alias Teiserver.TestLib

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

  describe "show clan" do
    test "renders show page", %{conn: conn} do
      clan = TestLib.make_clan("clans_show_clan")
      resp = get(conn, Routes.ts_clans_clan_path(conn, :show, clan.name))
      assert html_response(resp, 200) =~ "Details"
      assert html_response(resp, 200) =~ "clans_show_clan"
    end

    test "renders show nil item", %{conn: conn} do
      assert_error_sent 404, fn ->
        get(conn, Routes.ts_clans_clan_path(conn, :show, -1))
      end
    end
  end

  describe "set default" do
    test "set default - success", %{conn: conn, user: user} do
      clan = TestLib.make_clan("clans_default_clan_success")
      TestLib.make_clan_membership(clan.id, user.id)
      conn = get(conn, Routes.ts_clans_clan_path(conn, :set_default, clan.id))
      assert redirected_to(conn) == Routes.ts_clans_clan_path(conn, :show, clan.name)
      assert conn.private[:phoenix_flash]["success"] == "This is now your selected clan"
    end

    test "set default - no member", %{conn: conn} do
      clan = TestLib.make_clan("clans_default_clan_no_member")
      conn = get(conn, Routes.ts_clans_clan_path(conn, :set_default, clan.id))
      assert redirected_to(conn) == Routes.ts_clans_clan_path(conn, :show, clan.name)
      assert conn.private[:phoenix_flash]["success"] == nil
    end

    test "set default on nil item", %{conn: conn} do
      assert_error_sent 404, fn ->
        get(conn, Routes.ts_clans_clan_path(conn, :show, -1))
      end
    end
  end
end
