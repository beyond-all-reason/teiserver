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
        colour: "some colour",
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
