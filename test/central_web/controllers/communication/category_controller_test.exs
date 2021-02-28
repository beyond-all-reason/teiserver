defmodule CentralWeb.Communication.CategoryControllerTest do
  use CentralWeb.ConnCase

  alias Central.Communication
  alias Central.CommunicationTestLib

  alias Central.Helpers.GeneralTestLib

  setup do
    GeneralTestLib.conn_setup(~w(communication.blog))
  end

  @create_attrs %{colour: "some colour", icon: "far fa-home", name: "some name"}
  @update_attrs %{colour: "some updated colour", icon: "fas fa-wrench", name: "some updated name"}
  @invalid_attrs %{colour: nil, icon: nil, name: nil}

  describe "index" do
    test "lists all categories", %{conn: conn} do
      _ = CommunicationTestLib.category_fixture()
      _ = CommunicationTestLib.category_fixture()
      conn = get(conn, Routes.blog_category_path(conn, :index))
      assert html_response(conn, 200) =~ "Listing Categories"
    end
  end

  describe "new category" do
    test "renders form", %{conn: conn} do
      conn = get(conn, Routes.blog_category_path(conn, :new))
      assert html_response(conn, 200) =~ "Save changes"
    end
  end

  describe "create category" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, Routes.blog_category_path(conn, :create), category: @create_attrs)
      assert redirected_to(conn) == Routes.blog_category_path(conn, :index)

      new_category = Communication.list_categories(search: [name: @create_attrs.name])
      assert Enum.count(new_category) == 1
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.blog_category_path(conn, :create), category: @invalid_attrs)
      assert html_response(conn, 200) =~ "Oops, something went wrong!"
    end
  end

  describe "edit category" do
    test "renders form for editing nil", %{conn: conn} do
      assert_error_sent(404, fn ->
        get(conn, Routes.blog_category_path(conn, :edit, -1))
      end)
    end

    test "renders form for editing chosen category", %{conn: conn} do
      category = CommunicationTestLib.category_fixture()
      conn = get(conn, Routes.blog_category_path(conn, :edit, category))
      assert html_response(conn, 200) =~ "Save changes"
    end
  end

  describe "update category" do
    test "redirects when data is valid", %{conn: conn} do
      category = CommunicationTestLib.category_fixture()

      conn =
        put(conn, Routes.blog_category_path(conn, :update, category), category: @update_attrs)

      assert redirected_to(conn) == Routes.blog_category_path(conn, :index)

      conn = get(conn, Routes.blog_category_path(conn, :edit, category))
      assert html_response(conn, 200) =~ "some updated colour"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      category = CommunicationTestLib.category_fixture()

      conn =
        put(conn, Routes.blog_category_path(conn, :update, category), category: @invalid_attrs)

      assert html_response(conn, 200) =~ "Oops, something went wrong!"
    end

    test "renders errors when nil object", %{conn: conn} do
      assert_error_sent(404, fn ->
        put(conn, Routes.blog_category_path(conn, :update, -1), category: @invalid_attrs)
      end)
    end
  end

  describe "delete category" do
    test "deletes chosen category", %{conn: conn} do
      category = CommunicationTestLib.category_fixture()
      conn = delete(conn, Routes.blog_category_path(conn, :delete, category))
      assert redirected_to(conn) == Routes.blog_category_path(conn, :index)

      assert_error_sent(404, fn ->
        get(conn, Routes.blog_category_path(conn, :edit, category))
      end)
    end

    test "renders error for deleting nil item", %{conn: conn} do
      assert_error_sent(404, fn ->
        delete(conn, Routes.blog_category_path(conn, :delete, -1))
      end)
    end
  end
end
