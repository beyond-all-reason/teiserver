defmodule Teiserver.MicroblogFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Teiserver.Microblog` context.
  """
  alias Teiserver.{Microblog, AccountFixtures}

  @doc """
  Generate a tag.
  """
  def tag_fixture(attrs \\ %{}) do
    {:ok, tag} =
      attrs
      |> Enum.into(%{
        colour: "#AA0000",
        icon: "some icon",
        name: "some name"
      })
      |> Microblog.create_tag()

    tag
  end

  @doc """
  Generate a post.
  """
  def post_fixture(attrs \\ %{}) do
    user = AccountFixtures.user_fixture()

    {:ok, post} =
      attrs
      |> Enum.into(%{
        poster_id: user.id,
        contents: "some contents",
        discord_post_id: 42,
        title: "some title",
        view_count: 42
      })
      |> Microblog.create_post()

    post
  end

  @doc """
  Generate a post.
  """
  def post_with_tag_fixture(attrs \\ %{}) do
    user = AccountFixtures.user_fixture()
    tag = tag_fixture()

    {:ok, post} =
      attrs
      |> Enum.into(%{
        poster_id: user.id,
        contents: "some contents",
        discord_post_id: 42,
        title: "some title",
        view_count: 42
      })
      |> Microblog.create_post()

    post_tag = post_tag_fixture(post_id: post.id, tag_id: tag.id)

    {post, tag, post_tag}
  end

  @doc """
  Generate a post_tag.
  """
  def post_tag_fixture(attrs \\ %{}) do
    post = post_fixture()
    tag = tag_fixture()

    {:ok, post_tag} =
      attrs
      |> Enum.into(%{
        post_id: post.id,
        tag_id: tag.id
      })
      |> Microblog.create_post_tag()

    post_tag
  end

  @doc """
  Generate a poll_response.
  """
  def poll_response_fixture(attrs \\ %{}) do
    {:ok, poll_response} =
      attrs
      |> Enum.into(%{
        post_id: post_fixture().id,
        user_id: AccountFixtures.user_fixture().id,
        response: "A"
      })
      |> Microblog.create_poll_response()

    poll_response
  end

  @doc """
  Generate an upload.
  """
  def upload_fixture(attrs \\ %{}) do
    {:ok, upload} =
      attrs
      |> Enum.into(%{
        uploader_id: AccountFixtures.user_fixture().id,
        filename: "filename",
        type: "image",
        file_size: 123
      })
      |> Microblog.create_upload()

    upload
  end

  @doc """
  Generate a user_preference.
  """
  def user_preference_fixture(attrs \\ %{}) do
    user = AccountFixtures.user_fixture()

    {:ok, user_preference} =
      attrs
      |> Enum.into(%{
        user_id: user.id,
        disabled_posters: [1, 2],
        disabled_tags: [1, 2],
        enabled_posters: [1, 2],
        enabled_tags: [1, 2],
        tag_mode: "some tag_mode"
      })
      |> Microblog.create_user_preference()

    user_preference
  end
end
