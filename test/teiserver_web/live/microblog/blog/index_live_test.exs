defmodule TeiserverWeb.Microblog.Blog.IndexLiveTest do
  @moduledoc false
  use TeiserverWeb.ConnCase

  import Phoenix.LiveViewTest
  import Teiserver.MicroblogFixtures
  alias Central.Helpers.GeneralTestLib
  alias Teiserver.{TeiserverTestLib}

  defp auth_setup(_) do
    GeneralTestLib.conn_setup()
    |> TeiserverTestLib.conn_setup()
  end

  defp filler_posts(_) do
    tag1 = tag_fixture()
    tag2 = tag_fixture()
    tag3 = tag_fixture()

    post1 = post_fixture(title: "Post 1 title", contents: "Post 1 line1\n\nPost 1 fold line")
    _post1_tag1 = post_tag_fixture(post_id: post1.id, tag_id: tag1.id)
    _post1_tag2 = post_tag_fixture(post_id: post1.id, tag_id: tag2.id)

    post2 = post_fixture(title: "Post 2 title", contents: "Post 2 line1\n\nPost 2 fold line")
    _post2_tag1 = post_tag_fixture(post_id: post2.id, tag_id: tag1.id)
    _post2_tag3 = post_tag_fixture(post_id: post2.id, tag_id: tag3.id)

    post3 = post_fixture(title: "Post 3 title", contents: "Post 3 line1\n\nPost 3 fold line")
    _post3_tag2 = post_tag_fixture(post_id: post3.id, tag_id: tag2.id)
    _post3_tag3 = post_tag_fixture(post_id: post3.id, tag_id: tag3.id)

    %{post1: post1, post2: post2, post3: post3, tag1: tag1, tag2: tag2, tag3: tag3}
  end

  describe "Anon Index" do
    setup [:filler_posts]

    test "viewing the blog", %{conn: conn, post1: post1} do
      {:ok, index_live, html} = live(conn, ~p"/microblog")

      assert html =~ "RSS"
      assert html =~ "Post 1 title"
      assert html =~ "Post 2 title"
      assert html =~ "Post 3 title"

      assert html =~ "Post 1 line1"
      assert html =~ "Post 2 line1"
      assert html =~ "Post 3 line1"

      refute html =~ "Post 1 fold line"
      refute html =~ "Post 2 fold line"
      refute html =~ "Post 3 fold line"

      # Click to show a post
      index_live |> element("#posts-#{post1.id} a") |> render_click()
      assert_redirect(index_live, ~p"/microblog/show/#{post1.id}")

      {:ok, _show_live, html} = live(conn, ~p"/microblog/show/#{post1.id}")
      refute html =~ "RSS"
      assert html =~ "Post 1 title"
      refute html =~ "Post 2 title"
      refute html =~ "Post 3 title"

      assert html =~ "Post 1 line1"
      refute html =~ "Post 2 line1"
      refute html =~ "Post 3 line1"

      assert html =~ "Post 1 fold line"
      refute html =~ "Post 2 fold line"
      refute html =~ "Post 3 fold line"
    end
  end

  describe "Index" do
    setup [:filler_posts, :auth_setup]

    test "User without preferences", %{conn: conn, user: _user, post1: post1} do
      {:ok, index_live, html} = live(conn, ~p"/microblog")

      assert html =~ "RSS"
      assert html =~ "Post 1 title"
      assert html =~ "Post 2 title"
      assert html =~ "Post 3 title"

      assert html =~ "Post 1 line1"
      assert html =~ "Post 2 line1"
      assert html =~ "Post 3 line1"

      refute html =~ "Post 1 fold line"
      refute html =~ "Post 2 fold line"
      refute html =~ "Post 3 fold line"

      # Click to show a post
      index_live |> element("#posts-#{post1.id} a") |> render_click()
      assert_redirect(index_live, ~p"/microblog/show/#{post1.id}")

      {:ok, _show_live, html} = live(conn, ~p"/microblog/show/#{post1.id}")
      refute html =~ "RSS"
      assert html =~ "Post 1 title"
      refute html =~ "Post 2 title"
      refute html =~ "Post 3 title"

      assert html =~ "Post 1 line1"
      refute html =~ "Post 2 line1"
      refute html =~ "Post 3 line1"

      assert html =~ "Post 1 fold line"
      refute html =~ "Post 2 fold line"
      refute html =~ "Post 3 fold line"
    end

    test "Including preferences", %{conn: conn, user: user, post3: post3, tag1: tag1} do
      user_preference_fixture(%{
        user_id: user.id,
        tag_mode: "Block",
        enabled_tags: [],
        disabled_tags: [tag1.id],
        enabled_posters: [],
        disabled_posters: []
      })

      {:ok, index_live, html} = live(conn, ~p"/microblog")

      assert html =~ "RSS"
      refute html =~ "Post 1 title"
      refute html =~ "Post 2 title"
      assert html =~ "Post 3 title"

      refute html =~ "Post 1 line1"
      refute html =~ "Post 2 line1"
      assert html =~ "Post 3 line1"

      refute html =~ "Post 1 fold line"
      refute html =~ "Post 2 fold line"
      refute html =~ "Post 3 fold line"

      # Click to show a post
      index_live |> element("#posts-#{post3.id} a") |> render_click()
      assert_redirect(index_live, ~p"/microblog/show/#{post3.id}")

      {:ok, _show_live, html} = live(conn, ~p"/microblog/show/#{post3.id}")
      refute html =~ "RSS"
      refute html =~ "Post 1 title"
      refute html =~ "Post 2 title"
      assert html =~ "Post 3 title"

      refute html =~ "Post 1 line1"
      refute html =~ "Post 2 line1"
      assert html =~ "Post 3 line1"

      refute html =~ "Post 1 fold line"
      refute html =~ "Post 2 fold line"
      assert html =~ "Post 3 fold line"
    end
  end
end
