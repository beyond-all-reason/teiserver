# defmodule TeiserverWeb.Game.QueueControllerTest do
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
#     test "lists all queues", %{conn: conn} do
#       conn = get(conn, Routes.game_queue_path(conn, :index))
#       assert html_response(conn, 200) =~ "Listing Queues"
#     end
#   end

#   describe "new queue" do
#     test "renders form", %{conn: conn} do
#       conn = get(conn, Routes.game_queue_path(conn, :new))
#       assert html_response(conn, 200) =~ "Create"
#     end
#   end

#   describe "create queue" do
#     test "redirects to show when data is valid", %{conn: conn} do
#       conn = post(conn, Routes.game_queue_path(conn, :create), queue: @create_attrs)
#       assert redirected_to(conn) == Routes.game_queue_path(conn, :index)

#       new_queue = Game.list_queues(search: [name: @create_attrs.name])
#       assert Enum.count(new_queue) == 1
#     end

#     test "renders errors when data is invalid", %{conn: conn} do
#       conn = post(conn, Routes.game_queue_path(conn, :create), queue: @invalid_attrs)
#       assert html_response(conn, 200) =~ "Oops, something went wrong!"
#     end
#   end

#   describe "show queue" do
#     test "renders show page", %{conn: conn} do
#       queue = GameTestLib.queue_fixture()
#       resp = get(conn, Routes.game_queue_path(conn, :show, queue))
#       assert html_response(resp, 200) =~ "Edit queue"
#     end

#     test "renders show nil item", %{conn: conn} do
#       assert_error_sent 404, fn ->
#         get(conn, Routes.game_queue_path(conn, :show, -1))
#       end
#     end
#   end

#   describe "edit queue" do
#     test "renders form for editing nil", %{conn: conn} do
#       assert_error_sent 404, fn ->
#         get(conn, Routes.game_queue_path(conn, :edit, -1))
#       end
#     end

#     test "renders form for editing chosen queue", %{conn: conn} do
#       queue = GameTestLib.queue_fixture()
#       conn = get(conn, Routes.game_queue_path(conn, :edit, queue))
#       assert html_response(conn, 200) =~ "Save changes"
#     end
#   end

#   describe "update queue" do
#     test "redirects when data is valid", %{conn: conn} do
#       queue = GameTestLib.queue_fixture()
#       conn = put(conn, Routes.game_queue_path(conn, :update, queue), queue: @update_attrs)
#       assert redirected_to(conn) == Routes.game_queue_path(conn, :index)

#       conn = get(conn, Routes.game_queue_path(conn, :show, queue))
#       assert html_response(conn, 200) =~ "some updated colour"
#     end

#     test "renders errors when data is invalid", %{conn: conn} do
#       queue = GameTestLib.queue_fixture()
#       conn = put(conn, Routes.game_queue_path(conn, :update, queue), queue: @invalid_attrs)
#       assert html_response(conn, 200) =~ "Oops, something went wrong!"
#     end

#     test "renders errors when nil object", %{conn: conn} do
#       assert_error_sent 404, fn ->
#         put(conn, Routes.game_queue_path(conn, :update, -1), queue: @invalid_attrs)
#       end
#     end
#   end

#   describe "delete queue" do
#     test "deletes chosen queue", %{conn: conn} do
#       queue = GameTestLib.queue_fixture()
#       conn = delete(conn, Routes.game_queue_path(conn, :delete, queue))
#       assert redirected_to(conn) == Routes.game_queue_path(conn, :index)
#       assert_error_sent 404, fn ->
#         get(conn, Routes.game_queue_path(conn, :show, queue))
#       end
#     end

#     test "renders error for deleting nil item", %{conn: conn} do
#       assert_error_sent 404, fn ->
#         delete(conn, Routes.game_queue_path(conn, :delete, -1))
#       end
#     end
#   end
# end
