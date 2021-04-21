defmodule TeiserverWeb.Admin.ClanControllerTest do
  use CentralWeb.ConnCase

  alias Teiserver.TestLib

  alias Central.Helpers.GeneralTestLib
  setup do
    GeneralTestLib.conn_setup(Teiserver.TestLib.admin_permissions())
    |> Teiserver.TestLib.conn_setup
  end

  # @create_attrs %{colour: "some colour", icon: "far fa-home", name: "some name"}
  # @update_attrs %{colour: "some updated colour", icon: "fas fa-wrench", name: "some updated name"}
  # @invalid_attrs %{colour: nil, icon: nil, name: nil}

  describe "index" do
    test "lists all clans", %{conn: conn} do
      clan = TestLib.make_clan("admin_clan_list1")
      clan = TestLib.make_clan("admin_clan_list2")
      conn = get(conn, Routes.ts_admin_clan_path(conn, :index))
      assert html_response(conn, 200) =~ "Listing Clans"
    end
  end

#   describe "new clan" do
#     test "renders form", %{conn: conn} do
#       conn = get(conn, Routes.ts_admin_clan_path(conn, :new))
#       assert html_response(conn, 200) =~ "Create"
#     end
#   end

#   describe "create clan" do
#     test "redirects to show when data is valid", %{conn: conn} do
#       conn = post(conn, Routes.ts_admin_clan_path(conn, :create), clan: @create_attrs)
#       assert redirected_to(conn) == Routes.ts_admin_clan_path(conn, :index)

#       new_clan = Clan.list_clans(search: [name: @create_attrs.name])
#       assert Enum.count(new_clan) == 1
#     end

#     test "renders errors when data is invalid", %{conn: conn} do
#       conn = post(conn, Routes.ts_admin_clan_path(conn, :create), clan: @invalid_attrs)
#       assert html_response(conn, 200) =~ "Oops, something went wrong!"
#     end
#   end

#   describe "show clan" do
#     test "renders show page", %{conn: conn} do
#       clan = ClanTestLib.clan_fixture()
#       resp = get(conn, Routes.ts_admin_clan_path(conn, :show, clan))
#       assert html_response(resp, 200) =~ "Edit clan"
#     end

#     test "renders show nil item", %{conn: conn} do
#       assert_error_sent 404, fn ->
#         get(conn, Routes.ts_admin_clan_path(conn, :show, -1))
#       end
#     end
#   end

#   describe "edit clan" do
#     test "renders form for editing nil", %{conn: conn} do
#       assert_error_sent 404, fn ->
#         get(conn, Routes.ts_admin_clan_path(conn, :edit, -1))
#       end
#     end

#     test "renders form for editing chosen clan", %{conn: conn} do
#       clan = ClanTestLib.clan_fixture()
#       conn = get(conn, Routes.ts_admin_clan_path(conn, :edit, clan))
#       assert html_response(conn, 200) =~ "Save changes"
#     end
#   end

#   describe "update clan" do
#     test "redirects when data is valid", %{conn: conn} do
#       clan = ClanTestLib.clan_fixture()
#       conn = put(conn, Routes.ts_admin_clan_path(conn, :update, clan), clan: @update_attrs)
#       assert redirected_to(conn) == Routes.ts_admin_clan_path(conn, :index)

#       conn = get(conn, Routes.ts_admin_clan_path(conn, :show, clan))
#       assert html_response(conn, 200) =~ "some updated colour"
#     end

#     test "renders errors when data is invalid", %{conn: conn} do
#       clan = ClanTestLib.clan_fixture()
#       conn = put(conn, Routes.ts_admin_clan_path(conn, :update, clan), clan: @invalid_attrs)
#       assert html_response(conn, 200) =~ "Oops, something went wrong!"
#     end

#     test "renders errors when nil object", %{conn: conn} do
#       assert_error_sent 404, fn ->
#         put(conn, Routes.ts_admin_clan_path(conn, :update, -1), clan: @invalid_attrs)
#       end
#     end
#   end

#   describe "delete clan" do
#     test "deletes chosen clan", %{conn: conn} do
#       clan = ClanTestLib.clan_fixture()
#       conn = delete(conn, Routes.ts_admin_clan_path(conn, :delete, clan))
#       assert redirected_to(conn) == Routes.ts_admin_clan_path(conn, :index)
#       assert_error_sent 404, fn ->
#         get(conn, Routes.ts_admin_clan_path(conn, :show, clan))
#       end
#     end

#     test "renders error for deleting nil item", %{conn: conn} do
#       assert_error_sent 404, fn ->
#         delete(conn, Routes.ts_admin_clan_path(conn, :delete, -1))
#       end
#     end
#   end
end
