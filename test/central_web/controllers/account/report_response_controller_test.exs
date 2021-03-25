defmodule CentralWeb.Account.ReportResponseControllerTest do
  use CentralWeb.ConnCase

  alias Central.Account
  alias Central.AccountTestLib

  alias Central.Helpers.GeneralTestLib
  setup do
    GeneralTestLib.conn_setup(~w(horizon.manage))
  end

  @create_attrs %{name: "some name"}
  @update_attrs %{name: "some updated name"}
  @invalid_attrs %{name: nil}

  describe "index" do
    test "lists all report_responses", %{conn: conn} do
      conn = get(conn, Routes.account_report_response_path(conn, :index))
      assert html_response(conn, 200) =~ "Listing ReportResponses"
    end
  end

  describe "new report_response" do
    test "renders form", %{conn: conn} do
      conn = get(conn, Routes.account_report_response_path(conn, :new))
      assert html_response(conn, 200) =~ "Create"
    end
  end

  describe "create report_response" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, Routes.account_report_response_path(conn, :create), report_response: @create_attrs)
      assert redirected_to(conn) == Routes.account_report_response_path(conn, :index)

      new_report_response = Account.list_report_responses(search: [name: @create_attrs.name])
      assert Enum.count(new_report_response) == 1
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.account_report_response_path(conn, :create), report_response: @invalid_attrs)
      assert html_response(conn, 200) =~ "Oops, something went wrong!"
    end
  end

  describe "show report_response" do
    test "renders show page", %{conn: conn} do
      report_response = AccountTestLib.report_response_fixture()
      resp = get(conn, Routes.account_report_response_path(conn, :show, report_response))
      assert html_response(resp, 200) =~ "Edit report_response"
    end

    test "renders show nil item", %{conn: conn} do
      assert_error_sent 404, fn ->
        get(conn, Routes.account_report_response_path(conn, :show, -1))
      end
    end
  end

  describe "edit report_response" do
    test "renders form for editing nil", %{conn: conn} do
      assert_error_sent 404, fn ->
        get(conn, Routes.account_report_response_path(conn, :edit, -1))
      end
    end

    test "renders form for editing chosen report_response", %{conn: conn} do
      report_response = AccountTestLib.report_response_fixture()
      conn = get(conn, Routes.account_report_response_path(conn, :edit, report_response))
      assert html_response(conn, 200) =~ "Save changes"
    end
  end

  describe "update report_response" do
    test "redirects when data is valid", %{conn: conn} do
      report_response = AccountTestLib.report_response_fixture()
      conn = put(conn, Routes.account_report_response_path(conn, :update, report_response), report_response: @update_attrs)
      assert redirected_to(conn) == Routes.account_report_response_path(conn, :index)

      conn = get(conn, Routes.account_report_response_path(conn, :show, report_response))
      assert html_response(conn, 200) =~ "some updated"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      report_response = AccountTestLib.report_response_fixture()
      conn = put(conn, Routes.account_report_response_path(conn, :update, report_response), report_response: @invalid_attrs)
      assert html_response(conn, 200) =~ "Oops, something went wrong!"
    end

    test "renders errors when nil object", %{conn: conn} do
      assert_error_sent 404, fn ->
        put(conn, Routes.account_report_response_path(conn, :update, -1), report_response: @invalid_attrs)
      end
    end
  end

  describe "delete report_response" do
    test "deletes chosen report_response", %{conn: conn} do
      report_response = AccountTestLib.report_response_fixture()
      conn = delete(conn, Routes.account_report_response_path(conn, :delete, report_response))
      assert redirected_to(conn) == Routes.account_report_response_path(conn, :index)
      assert_error_sent 404, fn ->
        get(conn, Routes.account_report_response_path(conn, :show, report_response))
      end
    end

    test "renders error for deleting nil item", %{conn: conn} do
      assert_error_sent 404, fn ->
        delete(conn, Routes.account_report_response_path(conn, :delete, -1))
      end
    end
  end
end
