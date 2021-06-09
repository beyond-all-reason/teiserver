# defmodule TeiserverWeb.Battle.BattleLogControllerTest do
#   use TeiserverWeb.ConnCase

#   alias Teiserver.Battle
#   alias Teiserver.BattleTestLib

#   alias Teiserver.Helpers.GeneralTestLib
#   setup do
#     GeneralTestLib.conn_setup(~w(horizon.manage))
#   end

#   @create_attrs %{name: "some name"}
#   @update_attrs %{name: "some updated name"}
#   @invalid_attrs %{name: nil}

#   describe "index" do
#     test "lists all battle_logs", %{conn: conn} do
#       conn = get(conn, Routes.battle_battle_log_path(conn, :index))
#       assert html_response(conn, 200) =~ "Listing BattleLogs"
#     end
#   end

#   describe "show battle_log" do
#     test "renders show page", %{conn: conn} do
#       battle_log = BattleTestLib.battle_log_fixture()
#       resp = get(conn, Routes.battle_battle_log_path(conn, :show, battle_log))
#       assert html_response(resp, 200) =~ "Edit battle_log"
#     end

#     test "renders show nil item", %{conn: conn} do
#       assert_error_sent 404, fn ->
#         get(conn, Routes.battle_battle_log_path(conn, :show, -1))
#       end
#     end
#   end

#   describe "delete battle_log" do
#     test "deletes chosen battle_log", %{conn: conn} do
#       battle_log = BattleTestLib.battle_log_fixture()
#       conn = delete(conn, Routes.battle_battle_log_path(conn, :delete, battle_log))
#       assert redirected_to(conn) == Routes.battle_battle_log_path(conn, :index)
#       assert_error_sent 404, fn ->
#         get(conn, Routes.battle_battle_log_path(conn, :show, battle_log))
#       end
#     end

#     test "renders error for deleting nil item", %{conn: conn} do
#       assert_error_sent 404, fn ->
#         delete(conn, Routes.battle_battle_log_path(conn, :delete, -1))
#       end
#     end
#   end
# end
