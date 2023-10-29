# defmodule TeiserverWeb.Account.BadgeTypeControllerTest do
#   use TeiserverWeb.ConnCase

#   alias Teiserver.Account
#   alias Teiserver.AccountTestLib

#   alias Teiserver.Helpers.GeneralTestLib
#   setup do
#     GeneralTestLib.conn_setup(~w(horizon.manage))
#   end

#   @create_attrs %{colour: "#AA0000", icon: "fa-regular fa-home", name: "some name"}
#   @update_attrs %{colour: "#0000AA", icon: "fa-solid fa-wrench", name: "some updated name"}
#   @invalid_attrs %{colour: nil, icon: nil, name: nil}

#   describe "index" do
#     test "lists all badge_types", %{conn: conn} do
#       conn = get(conn, Routes.account_badge_type_path(conn, :index))
#       assert html_response(conn, 200) =~ "Listing BadgeTypes"
#     end
#   end

#   describe "new badge_type" do
#     test "renders form", %{conn: conn} do
#       conn = get(conn, Routes.account_badge_type_path(conn, :new))
#       assert html_response(conn, 200) =~ "Create"
#     end
#   end

#   describe "create badge_type" do
#     test "redirects to show when data is valid", %{conn: conn} do
#       conn = post(conn, Routes.account_badge_type_path(conn, :create), badge_type: @create_attrs)
#       assert redirected_to(conn) == Routes.account_badge_type_path(conn, :index)

#       new_badge_type = Account.list_badge_types(search: [name: @create_attrs.name])
#       assert Enum.count(new_badge_type) == 1
#     end

#     test "renders errors when data is invalid", %{conn: conn} do
#       conn = post(conn, Routes.account_badge_type_path(conn, :create), badge_type: @invalid_attrs)
#       assert html_response(conn, 200) =~ "Oops, something went wrong!"
#     end
#   end

#   describe "show badge_type" do
#     test "renders show page", %{conn: conn} do
#       badge_type = AccountTestLib.badge_type_fixture()
#       resp = get(conn, Routes.account_badge_type_path(conn, :show, badge_type))
#       assert html_response(resp, 200) =~ "Edit badge_type"
#     end

#     test "renders show nil item", %{conn: conn} do
#       assert_error_sent 404, fn ->
#         get(conn, Routes.account_badge_type_path(conn, :show, -1))
#       end
#     end
#   end

#   describe "edit badge_type" do
#     test "renders form for editing nil", %{conn: conn} do
#       assert_error_sent 404, fn ->
#         get(conn, Routes.account_badge_type_path(conn, :edit, -1))
#       end
#     end

#     test "renders form for editing chosen badge_type", %{conn: conn} do
#       badge_type = AccountTestLib.badge_type_fixture()
#       conn = get(conn, Routes.account_badge_type_path(conn, :edit, badge_type))
#       assert html_response(conn, 200) =~ "Save changes"
#     end
#   end

#   describe "update badge_type" do
#     test "redirects when data is valid", %{conn: conn} do
#       badge_type = AccountTestLib.badge_type_fixture()
#       conn = put(conn, Routes.account_badge_type_path(conn, :update, badge_type), badge_type: @update_attrs)
#       assert redirected_to(conn) == Routes.account_badge_type_path(conn, :index)

#       conn = get(conn, Routes.account_badge_type_path(conn, :show, badge_type))
#       assert html_response(conn, 200) =~ "#0000AA"
#     end

#     test "renders errors when data is invalid", %{conn: conn} do
#       badge_type = AccountTestLib.badge_type_fixture()
#       conn = put(conn, Routes.account_badge_type_path(conn, :update, badge_type), badge_type: @invalid_attrs)
#       assert html_response(conn, 200) =~ "Oops, something went wrong!"
#     end

#     test "renders errors when nil object", %{conn: conn} do
#       assert_error_sent 404, fn ->
#         put(conn, Routes.account_badge_type_path(conn, :update, -1), badge_type: @invalid_attrs)
#       end
#     end
#   end

#   describe "delete badge_type" do
#     test "deletes chosen badge_type", %{conn: conn} do
#       badge_type = AccountTestLib.badge_type_fixture()
#       conn = delete(conn, Routes.account_badge_type_path(conn, :delete, badge_type))
#       assert redirected_to(conn) == Routes.account_badge_type_path(conn, :index)
#       assert_error_sent 404, fn ->
#         get(conn, Routes.account_badge_type_path(conn, :show, badge_type))
#       end
#     end

#     test "renders error for deleting nil item", %{conn: conn} do
#       assert_error_sent 404, fn ->
#         delete(conn, Routes.account_badge_type_path(conn, :delete, -1))
#       end
#     end
#   end
# end
