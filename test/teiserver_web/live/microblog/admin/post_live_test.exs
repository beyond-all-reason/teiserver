defmodule TeiserverWeb.PostLiveTest do
  @moduledoc false
  use TeiserverWeb.ConnCase

  import Phoenix.LiveViewTest
  import Teiserver.MicroblogFixtures
  alias Teiserver.Microblog

  @create_attrs %{contents: "some contents", title: "some title"}
  @update_attrs %{contents: "some updated contents", title: "some updated title"}
  @invalid_attrs %{contents: nil, title: nil}

  defp auth_setup(_) do
    Teiserver.TeiserverTestLib.server_permissions()
    |> Central.Helpers.GeneralTestLib.conn_setup()
    |> Teiserver.TeiserverTestLib.conn_setup()
  end

  defp unauth_setup(_) do
    Central.Helpers.GeneralTestLib.conn_setup()
    |> Teiserver.TeiserverTestLib.conn_setup()
  end

  defp create_post(_) do
    {post, tag, post_tag} = post_with_tag_fixture()
    %{post: post, tag: tag, post_tag: post_tag}
  end

  describe "Anon auth test" do
    setup [:create_post]

    test "anon get posts", %{conn: conn} do
      conn = get(conn, ~p"/microblog/admin/posts")

      assert redirected_to(conn) == ~p"/login"
    end

    test "anon visit post", %{conn: conn, post: post} do
      conn = get(conn, ~p"/microblog/admin/posts/#{post}")

      assert redirected_to(conn) == ~p"/login"
    end

    test "anon live", %{conn: conn, post: post} do
      {:error, {:redirect, resp}} = live(conn, ~p"/microblog/admin/posts")

      assert resp.to == ~p"/login"

      {:error, {:redirect, resp}} = live(conn, ~p"/microblog/admin/posts/#{post}")

      assert resp.to == ~p"/login"
    end
  end

  describe "Basic auth test" do
    setup [:unauth_setup, :create_post]

    test "cannot visit admin posts", %{conn: conn} do
      {:error, {:redirect, resp}} = live(conn, ~p"/microblog/admin/posts")
      assert resp.to == ~p"/"
    end

    test "cannot visit an admin's post", %{post: post, conn: conn} do
      {:error, {:redirect, resp}} = live(conn, ~p"/microblog/admin/posts/#{post}")
      assert resp.to == ~p"/"
    end

    test "can visit my post", %{post: post, conn: conn} do
      {:ok, _show_live, html} = live(conn, ~p"/microblog/show/#{post}")
      refute html =~ "Delete post"
    end
  end

  describe "Index" do
    setup [:auth_setup, :create_post]

    test "lists all posts", %{conn: conn, post: post} do
      {:ok, _index_live, html} = live(conn, ~p"/microblog/admin/posts")

      assert html =~ "New post form"
      refute html =~ post.title

      # What if there were no posts?
      Microblog.delete_post(post)
      {:ok, _index_live, html} = live(conn, ~p"/microblog/admin/posts")

      assert html =~ "New post form"
      refute html =~ post.title
    end

    test "creates new post", %{conn: conn, tag: tag} do
      {:ok, index_live, _html} = live(conn, ~p"/microblog/admin/posts")

      index_live |> element("#tag-#{tag.id}") |> render_click()

      assert index_live
             |> form("#post-form", post: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#post-form", post: @create_attrs)
             |> render_submit()

      assert_redirect(index_live, ~p"/microblog")

      {:ok, _index_live, html} = live(conn, ~p"/microblog")
      assert html =~ @create_attrs.title
    end
  end

  describe "Edit" do
    setup [:auth_setup, :create_post]

    test "updates the post", %{conn: conn, post: post} do
      {:ok, show_live, html} = live(conn, ~p"/microblog/admin/posts/#{post}")

      assert html =~ "Update post"
      assert html =~ "Edit post"

      assert show_live
             |> form("#post-form", post: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#post-form", post: @update_attrs)
             |> render_submit()

      assert_redirect(show_live, ~p"/microblog/admin/posts/#{post}")

      {:ok, _show_live, html} = live(conn, ~p"/microblog/admin/posts/#{post}")
      assert html =~ "some updated contents"
    end

    test "Delete", %{conn: conn, post: post} do
      {:ok, show_live, html} = live(conn, ~p"/microblog/show/#{post}")

      assert html =~ "Delete post"

      show_live
      |> element("#delete-post-button")
      |> render_click()

      assert_redirect(show_live, ~p"/microblog")

      assert Microblog.get_post(post.id) == nil
    end
  end
end
