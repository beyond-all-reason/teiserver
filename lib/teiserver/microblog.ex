defmodule Teiserver.Microblog do
  @moduledoc false
  import Ecto.Query, warn: false

  @spec colours :: atom
  def colours(), do: :primary

  @spec icon :: String.t()
  def icon(), do: "fa-blog"

  alias Teiserver.Microblog.{Tag, TagLib}

  @spec list_tags() :: [Tag]
  defdelegate list_tags(), to: TagLib

  @spec list_tags(list) :: [Tag]
  defdelegate list_tags(args), to: TagLib

  @spec get_tag!(non_neg_integer()) :: Tag.t
  defdelegate get_tag!(tag_id), to: TagLib

  @spec get_tag(non_neg_integer()) :: Tag.t | nil
  defdelegate get_tag(tag_id), to: TagLib

  @spec create_tag() :: {:ok, Tag} | {:error, Ecto.Changeset}
  defdelegate create_tag(), to: TagLib

  @spec create_tag(map) :: {:ok, Tag} | {:error, Ecto.Changeset}
  defdelegate create_tag(attrs), to: TagLib

  @spec update_tag(Tag, map) :: {:ok, Tag} | {:error, Ecto.Changeset}
  defdelegate update_tag(tag, attrs), to: TagLib

  @spec delete_tag(Tag) :: {:ok, Tag} | {:error, Ecto.Changeset}
  defdelegate delete_tag(tag), to: TagLib

  @spec change_tag(Tag) :: Ecto.Changeset
  defdelegate change_tag(tag), to: TagLib

  @spec change_tag(Tag, map) :: Ecto.Changeset
  defdelegate change_tag(tag_type, attrs), to: TagLib



  alias Teiserver.Microblog.{Post, PostLib}

  @spec list_posts() :: [Post]
  defdelegate list_posts(), to: PostLib

  @spec list_posts(list) :: [Post]
  defdelegate list_posts(args), to: PostLib

  @spec get_post!(non_neg_integer()) :: Post.t
  defdelegate get_post!(post_id), to: PostLib

  @spec get_post!(non_neg_integer, list) :: Post.t
  defdelegate get_post!(post_id, args), to: PostLib

  @spec get_post(non_neg_integer()) :: Post.t | nil
  defdelegate get_post(post_id), to: PostLib

  @spec get_post(non_neg_integer(), list) :: Post.t | nil
  defdelegate get_post(post_id, args), to: PostLib

  @spec create_post() :: {:ok, Post} | {:error, Ecto.Changeset}
  defdelegate create_post(), to: PostLib

  @spec create_post(map) :: {:ok, Post} | {:error, Ecto.Changeset}
  defdelegate create_post(attrs), to: PostLib

  @spec update_post(Post, map) :: {:ok, Post} | {:error, Ecto.Changeset}
  defdelegate update_post(post, attrs), to: PostLib

  @spec delete_post(Post) :: {:ok, Post} | {:error, Ecto.Changeset}
  defdelegate delete_post(post), to: PostLib

  @spec change_post(Post) :: Ecto.Changeset
  defdelegate change_post(post), to: PostLib

  @spec change_post(Post, map) :: Ecto.Changeset
  defdelegate change_post(post_type, attrs), to: PostLib

  @spec increment_post_view_count(non_neg_integer()) :: Ecto.Changeset
  defdelegate increment_post_view_count(post_id), to: PostLib


  alias Teiserver.Microblog.{PostTag, PostTagLib}

  @spec list_post_tags() :: [PostTag]
  defdelegate list_post_tags(), to: PostTagLib

  @spec list_post_tags(list) :: [PostTag]
  defdelegate list_post_tags(args), to: PostTagLib

  @spec get_post_tag!(non_neg_integer(), non_neg_integer()) :: PostTag.t
  defdelegate get_post_tag!(post_id, tag_id), to: PostTagLib

  @spec get_post_tag(non_neg_integer(), non_neg_integer()) :: PostTag.t | nil
  defdelegate get_post_tag(post_id, tag_id), to: PostTagLib

  @spec create_post_tag() :: {:ok, PostTag} | {:error, Ecto.Changeset}
  defdelegate create_post_tag(), to: PostTagLib

  @spec create_post_tag(map) :: {:ok, PostTag} | {:error, Ecto.Changeset}
  defdelegate create_post_tag(attrs), to: PostTagLib

  @spec update_post_tag(PostTag, map) :: {:ok, PostTag} | {:error, Ecto.Changeset}
  defdelegate update_post_tag(post_tag, attrs), to: PostTagLib

  @spec delete_post_tag(PostTag) :: {:ok, PostTag} | {:error, Ecto.Changeset}
  defdelegate delete_post_tag(post_tag), to: PostTagLib

  @spec change_post_tag(PostTag) :: Ecto.Changeset
  defdelegate change_post_tag(post_tag), to: PostTagLib

  @spec change_post_tag(PostTag, map) :: Ecto.Changeset
  defdelegate change_post_tag(post_tag_type, attrs), to: PostTagLib

  @spec delete_post_tags(non_neg_integer(), [non_neg_integer()]) :: {:ok, PostTag} | {:error, Ecto.Changeset}
  defdelegate delete_post_tags(post_id, tag_ids), to: PostTagLib
end
