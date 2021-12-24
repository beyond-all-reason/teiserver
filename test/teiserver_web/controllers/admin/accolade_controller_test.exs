# defmodule TeiserverWeb.Account.AccoladeControllerTest do
#   use TeiserverWeb.ConnCase

#   alias Teiserver.Account
#   alias Teiserver.AccountTestLib

#   alias Teiserver.Helpers.GeneralTestLib
#   setup do
#     GeneralTestLib.conn_setup(~w(horizon.manage))
#   end

#   @create_attrs %{name: "some name"}
#   @update_attrs %{name: "some updated name"}
#   @invalid_attrs %{name: nil}

#   describe "index" do
#     test "lists all accolades", %{conn: conn} do
#       conn = get(conn, Routes.account_accolade_path(conn, :index))
#       assert html_response(conn, 200) =~ "Listing Accolades"
#     end
#   end

#   describe "new accolade" do
#     test "renders form", %{conn: conn} do
#       conn = get(conn, Routes.account_accolade_path(conn, :new))
#       assert html_response(conn, 200) =~ "Create"
#     end
#   end

#   describe "create accolade" do
#     test "redirects to show when data is valid", %{conn: conn} do
#       conn = post(conn, Routes.account_accolade_path(conn, :create), accolade: @create_attrs)
#       assert redirected_to(conn) == Routes.account_accolade_path(conn, :index)

#       new_accolade = Account.list_accolades(search: [name: @create_attrs.name])
#       assert Enum.count(new_accolade) == 1
#     end

#     test "renders errors when data is invalid", %{conn: conn} do
#       conn = post(conn, Routes.account_accolade_path(conn, :create), accolade: @invalid_attrs)
#       assert html_response(conn, 200) =~ "Oops, something went wrong!"
#     end
#   end

#   describe "show accolade" do
#     test "renders show page", %{conn: conn} do
#       accolade = AccountTestLib.accolade_fixture()
#       resp = get(conn, Routes.account_accolade_path(conn, :show, accolade))
#       assert html_response(resp, 200) =~ "Edit accolade"
#     end

#     test "renders show nil item", %{conn: conn} do
#       assert_error_sent 404, fn ->
#         get(conn, Routes.account_accolade_path(conn, :show, -1))
#       end
#     end
#   end

#   describe "edit accolade" do
#     test "renders form for editing nil", %{conn: conn} do
#       assert_error_sent 404, fn ->
#         get(conn, Routes.account_accolade_path(conn, :edit, -1))
#       end
#     end

#     test "renders form for editing chosen accolade", %{conn: conn} do
#       accolade = AccountTestLib.accolade_fixture()
#       conn = get(conn, Routes.account_accolade_path(conn, :edit, accolade))
#       assert html_response(conn, 200) =~ "Save changes"
#     end
#   end

#   describe "update accolade" do
#     test "redirects when data is valid", %{conn: conn} do
#       accolade = AccountTestLib.accolade_fixture()
#       conn = put(conn, Routes.account_accolade_path(conn, :update, accolade), accolade: @update_attrs)
#       assert redirected_to(conn) == Routes.account_accolade_path(conn, :index)

#       conn = get(conn, Routes.account_accolade_path(conn, :show, accolade))
#       assert html_response(conn, 200) =~ "some updated"
#     end

#     test "renders errors when data is invalid", %{conn: conn} do
#       accolade = AccountTestLib.accolade_fixture()
#       conn = put(conn, Routes.account_accolade_path(conn, :update, accolade), accolade: @invalid_attrs)
#       assert html_response(conn, 200) =~ "Oops, something went wrong!"
#     end

#     test "renders errors when nil object", %{conn: conn} do
#       assert_error_sent 404, fn ->
#         put(conn, Routes.account_accolade_path(conn, :update, -1), accolade: @invalid_attrs)
#       end
#     end
#   end

#   describe "delete accolade" do
#     test "deletes chosen accolade", %{conn: conn} do
#       accolade = AccountTestLib.accolade_fixture()
#       conn = delete(conn, Routes.account_accolade_path(conn, :delete, accolade))
#       assert redirected_to(conn) == Routes.account_accolade_path(conn, :index)
#       assert_error_sent 404, fn ->
#         get(conn, Routes.account_accolade_path(conn, :show, accolade))
#       end
#     end

#     test "renders error for deleting nil item", %{conn: conn} do
#       assert_error_sent 404, fn ->
#         delete(conn, Routes.account_accolade_path(conn, :delete, -1))
#       end
#     end
#   end
# end
