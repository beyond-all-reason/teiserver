defmodule CentralWeb.Communication.BlogFileControllerTest do
  use CentralWeb.ConnCase

  alias Central.Communication
  alias Central.CommunicationTestLib

  alias Central.Helpers.GeneralTestLib

  setup do
    GeneralTestLib.conn_setup(~w(communication.blog))
  end

  @create_attrs %{name: "some name", url: "some url"}
  @update_attrs %{name: "some updated name", url: "some updated url"}
  @invalid_attrs %{name: nil, url: nil}

  describe "index" do
    test "lists all blog_files", %{conn: conn} do
      _ = CommunicationTestLib.blog_file_fixture()
      _ = CommunicationTestLib.blog_file_fixture()
      conn = get(conn, Routes.blog_file_path(conn, :index))
      assert html_response(conn, 200) =~ "Listing Blog files"
    end
  end

  describe "new blog_file" do
    test "renders form", %{conn: conn} do
      conn = get(conn, Routes.blog_file_path(conn, :new))
      assert html_response(conn, 200) =~ "Create"
    end
  end

  describe "create blog_file" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, Routes.blog_file_path(conn, :create), blog_file: @create_attrs)
      assert redirected_to(conn) =~ Routes.blog_file_path(conn, :index)

      new_blog_file = Communication.list_blog_files(search: [name: @create_attrs.name])
      assert Enum.count(new_blog_file) == 1
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.blog_file_path(conn, :create), blog_file: @invalid_attrs)
      assert html_response(conn, 200) =~ "Oops, something went wrong!"
    end
  end

  describe "show blog_file" do
    test "renders show page", %{conn: conn} do
      blog_file = CommunicationTestLib.blog_file_fixture()
      resp = get(conn, Routes.blog_file_path(conn, :show, blog_file))
      assert html_response(resp, 200) =~ "Edit blog file"
    end

    test "renders show nil item", %{conn: conn} do
      assert_error_sent(404, fn ->
        get(conn, Routes.blog_file_path(conn, :show, -1))
      end)
    end
  end

  describe "edit blog_file" do
    test "renders form for editing nil", %{conn: conn} do
      assert_error_sent(404, fn ->
        get(conn, Routes.blog_file_path(conn, :edit, -1))
      end)
    end

    test "renders form for editing chosen blog_file", %{conn: conn} do
      blog_file = CommunicationTestLib.blog_file_fixture()
      conn = get(conn, Routes.blog_file_path(conn, :edit, blog_file))
      assert html_response(conn, 200) =~ "Save changes"
    end
  end

  describe "update blog_file" do
    test "redirects when data is valid", %{conn: conn} do
      blog_file = CommunicationTestLib.blog_file_fixture()
      conn = put(conn, Routes.blog_file_path(conn, :update, blog_file), blog_file: @update_attrs)
      assert redirected_to(conn) == Routes.blog_file_path(conn, :edit, blog_file)

      conn = get(conn, Routes.blog_file_path(conn, :show, blog_file))
      assert html_response(conn, 200) =~ "some updated name"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      blog_file = CommunicationTestLib.blog_file_fixture()
      conn = put(conn, Routes.blog_file_path(conn, :update, blog_file), blog_file: @invalid_attrs)
      assert html_response(conn, 200) =~ "Oops, something went wrong!"
    end

    test "renders errors when nil object", %{conn: conn} do
      assert_error_sent(404, fn ->
        put(conn, Routes.blog_file_path(conn, :update, -1), blog_file: @invalid_attrs)
      end)
    end
  end

  describe "delete blog_file" do
    test "deletes chosen blog_file", %{conn: conn} do
      blog_file = CommunicationTestLib.blog_file_fixture()
      conn = delete(conn, Routes.blog_file_path(conn, :delete, blog_file))
      assert redirected_to(conn) == Routes.blog_file_path(conn, :index)

      assert_error_sent(404, fn ->
        get(conn, Routes.blog_file_path(conn, :show, blog_file))
      end)
    end

    test "renders error for deleting nil item", %{conn: conn} do
      assert_error_sent(404, fn ->
        delete(conn, Routes.blog_file_path(conn, :delete, -1))
      end)
    end
  end
end
