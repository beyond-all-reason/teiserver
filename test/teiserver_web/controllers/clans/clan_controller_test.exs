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
      TestLib.make_clan("user_index_clan1")
      TestLib.make_clan("user_index_clan2")
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

  describe "creating invites" do
    test "create invite - success", %{conn: conn, user: user} do
      clan = TestLib.make_clan("clans_default_clan_success")
      TestLib.make_clan_membership(clan.id, user.id, %{"role" => "Admin"})
      user2 = GeneralTestLib.make_user()
      conn = post(conn, Routes.ts_clans_clan_path(conn, :create_invite), %{
        "teiserver_user" => "##{user2.id}",
        "clan_id" => clan.id
      })
      assert redirected_to(conn) == Routes.ts_clans_clan_path(conn, :show, clan.name) <> "#invites"
      assert conn.private[:phoenix_flash]["success"] == "User invited to clan."
    end

    test "create invite - you're not a mod/admin", %{conn: conn, user: user} do
      clan = TestLib.make_clan("clans_default_clan_success")
      TestLib.make_clan_membership(clan.id, user.id, %{"role" => "Member"})
      user2 = GeneralTestLib.make_user()
      conn = post(conn, Routes.ts_clans_clan_path(conn, :create_invite), %{
        "teiserver_user" => "##{user2.id}",
        "clan_id" => clan.id
      })
      assert redirected_to(conn) == Routes.ts_clans_clan_path(conn, :show, clan.name) <> "#invites"
      assert conn.private[:phoenix_flash]["danger"] == "You cannot send out invites for this clan."
    end

    test "create invite - you're not a member", %{conn: conn} do
      clan = TestLib.make_clan("clans_default_clan_success")
      user2 = GeneralTestLib.make_user()
      conn = post(conn, Routes.ts_clans_clan_path(conn, :create_invite), %{
        "teiserver_user" => "##{user2.id}",
        "clan_id" => clan.id
      })
      assert redirected_to(conn) == "/"
      assert conn.private[:phoenix_flash]["danger"] == "You are not a member of this clan."
    end
  end

  describe "removing invites" do

  end

  describe "responding to invites" do

  end

  describe "promote member" do
    test "promote member - success", %{conn: conn, user: user} do
      clan = TestLib.make_clan("clans_default_clan_success")
      TestLib.make_clan_membership(clan.id, user.id, %{"role" => "Admin"})
      user2 = GeneralTestLib.make_user()
      TestLib.make_clan_membership(clan.id, user2.id, %{"role" => "Member"})
      conn = put(conn, Routes.ts_clans_clan_path(conn, :promote, clan.id, user2.id))
      assert redirected_to(conn) == Routes.ts_clans_clan_path(conn, :show, clan.name) <> "#members"
      assert conn.private[:phoenix_flash]["info"] == "User promoted."
    end

    test "promote member - you're not a mod/admin", %{conn: conn, user: user} do
      clan = TestLib.make_clan("clans_default_clan_success")
      TestLib.make_clan_membership(clan.id, user.id, %{"role" => "Member"})
      user2 = GeneralTestLib.make_user()
      TestLib.make_clan_membership(clan.id, user2.id, %{"role" => "Member"})
      conn = put(conn, Routes.ts_clans_clan_path(conn, :promote, clan.id, user2.id))
      assert redirected_to(conn) == Routes.ts_clans_clan_path(conn, :show, clan.name) <> "#members"
      assert conn.private[:phoenix_flash]["danger"] == "No permissions."
    end

    test "promote member - you're not a member", %{conn: conn} do
      clan = TestLib.make_clan("clans_default_clan_success")
      user2 = GeneralTestLib.make_user()
      TestLib.make_clan_membership(clan.id, user2.id, %{"role" => "Member"})
      conn = put(conn, Routes.ts_clans_clan_path(conn, :promote, clan.id, user2.id))
      assert redirected_to(conn) == "/"
      assert conn.private[:phoenix_flash]["danger"] == "You are not a member of this clan."
    end
  end

  describe "demote member" do

  end

  describe "remove member" do

  end
end
