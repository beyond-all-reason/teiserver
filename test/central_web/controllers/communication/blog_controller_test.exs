defmodule CentralWeb.Communication.BlogControllerTest do
  use CentralWeb.ConnCase

  alias Central.CommunicationTestLib
  alias Central.Helpers.GeneralTestLib

  setup do
    GeneralTestLib.conn_setup(~w(communication.blog))
  end

  describe "list" do
    test "lists all posts", %{conn: conn} do
      _ = CommunicationTestLib.post_fixture()
      _ = CommunicationTestLib.post_fixture()
      conn = get(conn, Routes.blog_path(conn, :index))
      assert html_response(conn, 200) =~ "blog"
    end

    test "list by tag", %{conn: conn} do
      _ = CommunicationTestLib.post_fixture()
      _ = CommunicationTestLib.post_fixture()
      conn = get(conn, Routes.blog_path(conn, :tag, "Tag 1"))
      assert html_response(conn, 200) =~ "blog"
    end

    test "list by category", %{conn: conn} do
      p1 = CommunicationTestLib.post_fixture()
      _ = CommunicationTestLib.post_fixture()
      conn = get(conn, Routes.blog_path(conn, :category, p1.category_id))
      assert html_response(conn, 200) =~ "blog"
    end
  end

  describe "show post" do
    test "renders show page", %{conn: conn} do
      post = CommunicationTestLib.post_fixture()
      resp = get(conn, Routes.blog_path(conn, :show, post.url_slug))
      assert html_response(resp, 200) =~ "No comments"
    end

    test "renders show nil item", %{conn: conn} do
      resp = get(conn, Routes.blog_path(conn, :show, "___"))

      assert html_response(resp, 200) =~
               "Unfortunately it appears this post either doesn't exist or has yet to be published."
    end
  end

  describe "comments" do
    test "submit for nil item", %{conn: conn} do
      resp = post(conn, Routes.blog_path(conn, :add_comment, -1), comment: "comment content")

      assert html_response(resp, 200) =~
               "Unfortunately it appears this post either doesn't exist or has yet to be published."
    end

    test "renders form for editing chosen post", %{conn: conn} do
      post = CommunicationTestLib.post_fixture()
      conn = post(conn, Routes.blog_path(conn, :add_comment, post), comment: "comment content")
      assert redirected_to(conn) == Routes.blog_path(conn, :show, post.url_slug)
    end
  end

  describe "file" do
    # test "show file", %{conn: conn} do
    #   blog_file = CommunicationTestLib.blog_file_fixture()
    #   conn = get conn, Routes.blog_path(conn, :show_file, blog_file.url)
    #   assert html_response(conn, 200) =~ "some updated title"
    # end

    test "renders errors when nil object", %{conn: conn} do
      assert_error_sent(404, fn ->
        get(conn, Routes.blog_path(conn, :show_file, "___"))
      end)
    end
  end
end
