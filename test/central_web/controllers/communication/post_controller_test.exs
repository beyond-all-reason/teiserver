defmodule CentralWeb.Communication.PostControllerTest do
  use CentralWeb.ConnCase

  alias Central.Communication
  alias Central.CommunicationTestLib

  alias Central.Helpers.GeneralTestLib

  setup do
    GeneralTestLib.conn_setup(~w(communication.blog))
  end

  @create_attrs %{
    title: "some title",
    url_slug: "some url_slug",
    content: "some content",
    short_content: "some short_content"
  }
  @update_attrs %{
    title: "some updated title",
    url_slug: "some updated url_slug",
    content: "some updated content",
    short_content: "some updated short_content"
  }
  @invalid_attrs %{title: nil}

  describe "index" do
    test "lists all posts", %{conn: conn} do
      _ = CommunicationTestLib.post_fixture()
      _ = CommunicationTestLib.post_fixture()
      conn = get(conn, Routes.blog_post_path(conn, :index))
      assert html_response(conn, 200) =~ "Listing Posts"
    end
  end

  describe "new post" do
    test "redirects because no categories", %{conn: conn} do
      conn = get(conn, Routes.blog_post_path(conn, :new))
      assert redirected_to(conn) =~ Routes.blog_category_path(conn, :new)
    end

    test "renders form", %{conn: conn} do
      _ = CommunicationTestLib.post_fixture()
      conn = get(conn, Routes.blog_post_path(conn, :new))
      assert html_response(conn, 200) =~ "Create"
    end
  end

  describe "create post" do
    test "redirects to show when data is valid", %{conn: conn} do
      category = CommunicationTestLib.category_fixture()

      conn =
        post(conn, Routes.blog_post_path(conn, :create),
          post: Map.merge(@create_attrs, %{"category_id" => category.id})
        )

      assert redirected_to(conn) =~ Routes.blog_post_path(conn, :index)

      new_post = Communication.list_posts(search: [title: @create_attrs.title])
      assert Enum.count(new_post) == 1
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.blog_post_path(conn, :create), post: @invalid_attrs)
      assert html_response(conn, 200) =~ "Oops, something went wrong!"
    end
  end

  describe "show post" do
    test "renders show page", %{conn: conn} do
      post = CommunicationTestLib.post_fixture()
      resp = get(conn, Routes.blog_post_path(conn, :show, post))
      assert html_response(resp, 200) =~ "Edit post"
    end

    test "renders show nil item", %{conn: conn} do
      assert_error_sent(404, fn ->
        get(conn, Routes.blog_post_path(conn, :show, -1))
      end)
    end
  end

  describe "edit post" do
    test "renders form for editing nil", %{conn: conn} do
      assert_error_sent(404, fn ->
        get(conn, Routes.blog_post_path(conn, :edit, -1))
      end)
    end

    test "renders form for editing chosen post", %{conn: conn} do
      post = CommunicationTestLib.post_fixture()
      conn = get(conn, Routes.blog_post_path(conn, :edit, post))
      assert html_response(conn, 200) =~ "Save changes"
    end
  end

  describe "update post" do
    test "redirects when data is valid", %{conn: conn} do
      post = CommunicationTestLib.post_fixture()
      conn = put(conn, Routes.blog_post_path(conn, :update, post), post: @update_attrs)
      assert redirected_to(conn) == Routes.blog_post_path(conn, :show, post)

      conn = get(conn, Routes.blog_post_path(conn, :show, post))
      assert html_response(conn, 200) =~ "some updated title"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      post = CommunicationTestLib.post_fixture()
      conn = put(conn, Routes.blog_post_path(conn, :update, post), post: @invalid_attrs)
      assert html_response(conn, 200) =~ "Oops, something went wrong!"
    end

    test "renders errors when nil object", %{conn: conn} do
      assert_error_sent(404, fn ->
        put(conn, Routes.blog_post_path(conn, :update, -1), post: @invalid_attrs)
      end)
    end
  end

  describe "delete post" do
    test "deletes chosen post", %{conn: conn} do
      post = CommunicationTestLib.post_fixture()
      conn = delete(conn, Routes.blog_post_path(conn, :delete, post))
      assert redirected_to(conn) == Routes.blog_post_path(conn, :index)

      assert_error_sent(404, fn ->
        get(conn, Routes.blog_post_path(conn, :show, post))
      end)
    end

    test "renders error for deleting nil item", %{conn: conn} do
      assert_error_sent(404, fn ->
        delete(conn, Routes.blog_post_path(conn, :delete, -1))
      end)
    end
  end
end
