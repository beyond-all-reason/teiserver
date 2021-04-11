# defmodule TeiserverWeb.Game.PartyControllerTest do
#   use TeiserverWeb.ConnCase

#   alias Teiserver.Game
#   alias Teiserver.GameTestLib

#   alias Teiserver.Helpers.GeneralTestLib
#   setup do
#     GeneralTestLib.conn_setup(~w(horizon.manage))
#   end

#   @create_attrs %{colour: "some colour", icon: "far fa-home", name: "some name"}
#   @update_attrs %{colour: "some updated colour", icon: "fas fa-wrench", name: "some updated name"}
#   @invalid_attrs %{colour: nil, icon: nil, name: nil}

#   describe "index" do
#     test "lists all parties", %{conn: conn} do
#       conn = get(conn, Routes.game_party_path(conn, :index))
#       assert html_response(conn, 200) =~ "Listing Parties"
#     end
#   end

#   describe "new party" do
#     test "renders form", %{conn: conn} do
#       conn = get(conn, Routes.game_party_path(conn, :new))
#       assert html_response(conn, 200) =~ "Create"
#     end
#   end

#   describe "create party" do
#     test "redirects to show when data is valid", %{conn: conn} do
#       conn = post(conn, Routes.game_party_path(conn, :create), party: @create_attrs)
#       assert redirected_to(conn) == Routes.game_party_path(conn, :index)

#       new_party = Game.list_parties(search: [name: @create_attrs.name])
#       assert Enum.count(new_party) == 1
#     end

#     test "renders errors when data is invalid", %{conn: conn} do
#       conn = post(conn, Routes.game_party_path(conn, :create), party: @invalid_attrs)
#       assert html_response(conn, 200) =~ "Oops, something went wrong!"
#     end
#   end

#   describe "show party" do
#     test "renders show page", %{conn: conn} do
#       party = GameTestLib.party_fixture()
#       resp = get(conn, Routes.game_party_path(conn, :show, party))
#       assert html_response(resp, 200) =~ "Edit party"
#     end

#     test "renders show nil item", %{conn: conn} do
#       assert_error_sent 404, fn ->
#         get(conn, Routes.game_party_path(conn, :show, -1))
#       end
#     end
#   end

#   describe "edit party" do
#     test "renders form for editing nil", %{conn: conn} do
#       assert_error_sent 404, fn ->
#         get(conn, Routes.game_party_path(conn, :edit, -1))
#       end
#     end

#     test "renders form for editing chosen party", %{conn: conn} do
#       party = GameTestLib.party_fixture()
#       conn = get(conn, Routes.game_party_path(conn, :edit, party))
#       assert html_response(conn, 200) =~ "Save changes"
#     end
#   end

#   describe "update party" do
#     test "redirects when data is valid", %{conn: conn} do
#       party = GameTestLib.party_fixture()
#       conn = put(conn, Routes.game_party_path(conn, :update, party), party: @update_attrs)
#       assert redirected_to(conn) == Routes.game_party_path(conn, :index)

#       conn = get(conn, Routes.game_party_path(conn, :show, party))
#       assert html_response(conn, 200) =~ "some updated colour"
#     end

#     test "renders errors when data is invalid", %{conn: conn} do
#       party = GameTestLib.party_fixture()
#       conn = put(conn, Routes.game_party_path(conn, :update, party), party: @invalid_attrs)
#       assert html_response(conn, 200) =~ "Oops, something went wrong!"
#     end

#     test "renders errors when nil object", %{conn: conn} do
#       assert_error_sent 404, fn ->
#         put(conn, Routes.game_party_path(conn, :update, -1), party: @invalid_attrs)
#       end
#     end
#   end

#   describe "delete party" do
#     test "deletes chosen party", %{conn: conn} do
#       party = GameTestLib.party_fixture()
#       conn = delete(conn, Routes.game_party_path(conn, :delete, party))
#       assert redirected_to(conn) == Routes.game_party_path(conn, :index)
#       assert_error_sent 404, fn ->
#         get(conn, Routes.game_party_path(conn, :show, party))
#       end
#     end

#     test "renders error for deleting nil item", %{conn: conn} do
#       assert_error_sent 404, fn ->
#         delete(conn, Routes.game_party_path(conn, :delete, -1))
#       end
#     end
#   end
# end
