defmodule CentralWeb.Account.ReportControllerTest do
  use CentralWeb.ConnCase

  alias Central.Account.AccountTestLib

  alias Central.Helpers.GeneralTestLib

  setup do
    GeneralTestLib.conn_setup(~w(admin.report))
  end

  # @create_attrs %{name: "some name"}
  # @update_attrs %{name: "some updated name"}
  # @invalid_attrs %{name: nil}

  describe "index" do
    test "lists all reports", %{conn: conn} do
      conn = get(conn, Routes.admin_report_path(conn, :index))
      assert html_response(conn, 200) =~ "Listing Reports"
    end
  end

  # describe "new report" do
  #   test "renders form", %{conn: conn} do
  #     conn = get(conn, Routes.admin_report_path(conn, :new))
  #     assert html_response(conn, 200) =~ "Create"
  #   end
  # end

  # describe "create report" do
  #   test "redirects to show when data is valid", %{conn: conn} do
  #     conn = post(conn, Routes.admin_report_path(conn, :create), report: @create_attrs)
  #     assert redirected_to(conn) == Routes.admin_report_path(conn, :index)

  #     new_report = Account.list_reports(search: [name: @create_attrs.name])
  #     assert Enum.count(new_report) == 1
  #   end

  #   test "renders errors when data is invalid", %{conn: conn} do
  #     conn = post(conn, Routes.admin_report_path(conn, :create), report: @invalid_attrs)
  #     assert html_response(conn, 200) =~ "Oops, something went wrong!"
  #   end
  # end

  describe "show report" do
    test "renders show page", %{conn: conn} do
      report = AccountTestLib.report_fixture()
      resp = get(conn, Routes.admin_report_path(conn, :show, report))
      assert html_response(resp, 200) =~ "More reports of this user"
    end

    test "renders show nil item", %{conn: conn} do
      assert_error_sent 404, fn ->
        get(conn, Routes.admin_report_path(conn, :show, -1))
      end
    end
  end

  # describe "respond form" do
  #   test "renders form for editing nil", %{conn: conn} do
  #     assert_error_sent 404, fn ->
  #       get(conn, Routes.admin_report_path(conn, :edit, -1))
  #     end
  #   end

  #   test "renders form for editing chosen report", %{conn: conn} do
  #     report = AccountTestLib.report_fixture()
  #     conn = get(conn, Routes.admin_report_path(conn, :edit, report))
  #     assert html_response(conn, 200) =~ "Save changes"
  #   end
  # end

  # describe "respond post" do
  #   test "redirects when data is valid", %{conn: conn} do
  #     report = AccountTestLib.report_fixture()
  #     conn = put(conn, Routes.admin_report_path(conn, :update, report), report: @update_attrs)
  #     assert redirected_to(conn) == Routes.admin_report_path(conn, :index)

  #     conn = get(conn, Routes.admin_report_path(conn, :show, report))
  #     assert html_response(conn, 200) =~ "some updated"
  #   end

  #   test "renders errors when data is invalid", %{conn: conn} do
  #     report = AccountTestLib.report_fixture()
  #     conn = put(conn, Routes.admin_report_path(conn, :update, report), report: @invalid_attrs)
  #     assert html_response(conn, 200) =~ "Oops, something went wrong!"
  #   end

  #   test "renders errors when nil object", %{conn: conn} do
  #     assert_error_sent 404, fn ->
  #       put(conn, Routes.admin_report_path(conn, :update, -1), report: @invalid_attrs)
  #     end
  #   end
  # end
end
