defmodule CentralWeb.Communication.CommentControllerTest do
  use CentralWeb.ConnCase

  alias Central.CommunicationTestLib
  alias Central.Helpers.GeneralTestLib

  setup do
    GeneralTestLib.conn_setup(~w(communication.blog))
  end

  describe "index" do
    test "lists all comments", %{conn: conn} do
      _ = CommunicationTestLib.comment_fixture()
      _ = CommunicationTestLib.comment_fixture()
      conn = get(conn, Routes.blog_comment_path(conn, :index))
      assert html_response(conn, 200) =~ "Listing Comments"
    end
  end

  describe "show comment" do
    test "renders show page", %{conn: conn} do
      comment = CommunicationTestLib.comment_fixture()
      resp = get(conn, Routes.blog_comment_path(conn, :show, comment))
      assert html_response(resp, 200) =~ "<i class='far fa-fw fa-trash'></i> Delete"
    end

    test "renders show nil item", %{conn: conn} do
      assert_error_sent(404, fn ->
        get(conn, Routes.blog_comment_path(conn, :show, -1))
      end)
    end
  end

  describe "delete comment" do
    test "deletes chosen comment", %{conn: conn} do
      comment = CommunicationTestLib.comment_fixture()
      conn = delete(conn, Routes.blog_comment_path(conn, :delete, comment))

      assert redirected_to(conn) ==
               Routes.blog_post_path(conn, :show, comment.post_id) <> "#comments_tab"

      assert_error_sent(404, fn ->
        get(conn, Routes.blog_comment_path(conn, :show, comment.id))
      end)
    end

    test "renders error for deleting nil item", %{conn: conn} do
      assert_error_sent(404, fn ->
        delete(conn, Routes.blog_comment_path(conn, :delete, -1))
      end)
    end
  end
end
