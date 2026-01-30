defmodule TeiserverWeb.Microblog.RssControllerTest do
  @moduledoc false
  use TeiserverWeb.ConnCase
  import Teiserver.MicroblogFixtures

  defp auth_setup(_) do
    Central.Helpers.GeneralTestLib.conn_setup()
    |> Teiserver.TeiserverTestLib.conn_setup()
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

  describe "Anon" do
    setup [:filler_posts]

    test "viewing the feed", %{conn: conn, post1: post1} do
      conn = get(conn, ~p"/microblog/rss")
      resp = response(conn, 200)

      assert resp =~ post1.title
    end
  end

  describe "XML escaping" do
    setup do
      tag = tag_fixture(name: "Test&Tag")

      post =
        post_fixture(
          title: "Q&A Session <test>",
          contents: "Some content with & and < symbols"
        )

      _post_tag = post_tag_fixture(post_id: post.id, tag_id: tag.id)
      %{special_post: post, tag: tag}
    end

    test "special chars escaped", %{conn: conn} do
      conn = get(conn, ~p"/microblog/rss")
      resp = response(conn, 200)
      assert resp =~ "Q&amp;A Session"
      assert resp =~ "&lt;test&gt;"
      # Verify the tags are escaped too
      assert resp =~ "Test&amp;Tag"
      refute resp =~ "<title>Q&A"
    end
  end

  describe "Auth" do
    setup [:filler_posts, :auth_setup]

    test "viewing the feed", %{conn: conn, post1: post1} do
      conn = get(conn, ~p"/microblog/rss")
      resp = response(conn, 200)

      assert resp =~ post1.title
    end
  end
end
