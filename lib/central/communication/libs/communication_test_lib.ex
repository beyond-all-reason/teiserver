defmodule Central.CommunicationTestLib do
  @moduledoc false
  alias Central.Communication
  alias Central.Helpers.GeneralTestLib

  def category_fixture(), do: new_category()

  def new_category(params \\ %{}) do
    attrs =
      Map.merge(
        %{
          "name" => "Name",
          "colour" => "#000000",
          "icon" => "fa-regular fa-home",
          "public" => true
        },
        params
      )

    {:ok, c} = Communication.create_category(attrs)
    c
  end

  def post_fixture(),
    do:
      new_post(%{"category_id" => new_category().id, "poster_id" => GeneralTestLib.make_user().id})

  def new_post(params \\ %{}) do
    attrs =
      Map.merge(
        %{
          "url_slug" => "url_slug#{:rand.uniform(999_999)}",
          "title" => "title",
          "content" => "content\ncontent",
          "short_content" => "content",
          "live_from" => "Now",
          "allow_comments" => true,
          "tags" => ["Tag 1", "Tag 2"],
          "visible" => true
        },
        params
      )

    {:ok, p} = Communication.create_post(attrs)
    p
  end

  def comment_fixture(),
    do:
      new_comment(%{"post_id" => post_fixture().id, "poster_id" => GeneralTestLib.make_user().id})

  def new_comment(params \\ %{}) do
    attrs =
      Map.merge(
        %{
          "content" => "comment content",
          "poster_name" => nil,
          "approved" => true
        },
        params
      )

    {:ok, c} = Communication.create_comment(attrs)
    c
  end

  def blog_file_fixture(), do: new_blog_file()

  def new_blog_file(params \\ %{}) do
    attrs =
      Map.merge(
        %{
          "name" => "Name",
          "url" => "some_url#{:rand.uniform(999_999)}",
          "file_ext" => "png",
          "file_size" => 1_024_000_000
        },
        params
      )

    {:ok, s} = Communication.create_blog_file(attrs)
    s
  end
end
