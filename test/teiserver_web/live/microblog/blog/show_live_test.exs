defmodule TeiserverWeb.Blog.Blog.ShowLiveTest do
  @moduledoc false
  use TeiserverWeb.ConnCase

  import Phoenix.LiveViewTest
  import Teiserver.MicroblogFixtures
  alias Central.Helpers.GeneralTestLib
  alias Teiserver.{TeiserverTestLib}

  defp auth(_) do
    GeneralTestLib.conn_setup()
    |> TeiserverTestLib.conn_setup()
  end

  defp filler_post(_) do
    tag1 = tag_fixture()
    tag2 = tag_fixture()

    post =
      post_fixture(
        title: "Post 1 title",
        contents: "Post 1 line1\n\nPost 1 fold line",
        poll_choices: ["PollOpt 1", "PollOpt 2", "PollOpt 3"]
      )

    _post_tag1 = post_tag_fixture(post_id: post.id, tag_id: tag1.id)
    _post_tag2 = post_tag_fixture(post_id: post.id, tag_id: tag2.id)

    %{post: post, tag1: tag1, tag2: tag2}
  end

  describe "Anon Show" do
    setup [:filler_post]

    test "viewing the blog", %{conn: conn, post: post} do
      {:ok, show_live, html} = live(conn, ~p"/microblog/show/#{post.id}")

      assert html =~ "Post 1 title"
      assert html =~ "Post 1 line1"
      assert html =~ "Post 1 fold line"
      assert html =~ "PollOpt 1 - 0"
      assert html =~ "PollOpt 2 - 0"
      assert html =~ "PollOpt 3 - 0"
      refute html =~ "Vote in the poll"

      # Now click a poll button, should have no effect because we're not logged in
      render_click(show_live, "poll-choice", %{"choice" => "PollOpt 1"})

      # Due to the delays in various pub-sub parts this won't update right away so we'll just call the page again
      {:ok, _show_live, html} = live(conn, ~p"/microblog/show/#{post.id}")

      refute html =~ "Vote in the poll"
      assert html =~ "PollOpt 1 - 0"
      assert html =~ "PollOpt 2 - 0"
      assert html =~ "PollOpt 3 - 0"
    end
  end

  describe "Auth Show" do
    setup [:filler_post, :auth]

    test "User", %{conn: conn, user: _user, post: post} do
      {:ok, show_live, html} = live(conn, ~p"/microblog/show/#{post.id}")

      assert html =~ "Post 1 title"
      assert html =~ "Post 1 line1"
      assert html =~ "Post 1 fold line"
      assert html =~ "PollOpt 1 - 0"
      assert html =~ "PollOpt 2 - 0"
      assert html =~ "PollOpt 3 - 0"
      assert html =~ "Vote in the poll"

      # Now click a poll button, should have no effect because we're not logged in
      render_click(show_live, "poll-choice", %{"choice" => "PollOpt 1"})
      # Due to the delays in various pub-sub parts this won't update right away
      {:ok, _show_live, html} = live(conn, ~p"/microblog/show/#{post.id}")

      assert html =~ "Vote in the poll"
      assert html =~ "PollOpt 1 - 1"
      assert html =~ "PollOpt 2 - 0"
      assert html =~ "PollOpt 3 - 0"

      # Now lets change our vote
      render_click(show_live, "poll-choice", %{"choice" => "PollOpt 2"})
      # Due to the delays in various pub-sub parts this won't update right away
      {:ok, _show_live, html} = live(conn, ~p"/microblog/show/#{post.id}")

      assert html =~ "Vote in the poll"
      assert html =~ "PollOpt 1 - 0"
      assert html =~ "PollOpt 2 - 1"
      assert html =~ "PollOpt 3 - 0"
    end
  end
end
