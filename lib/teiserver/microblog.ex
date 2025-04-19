defmodule Teiserver.Microblog do
  @moduledoc """
  Main point of usage for the microblog system
  """

  @spec colours :: atom
  def colours(), do: :primary

  @spec icon :: String.t()
  def icon(), do: "fa-blog"

  alias Teiserver.Microblog.{Tag, TagLib}

  @spec list_tags() :: [Tag]
  defdelegate list_tags(), to: TagLib

  @spec list_tags(list) :: [Tag]
  defdelegate list_tags(args), to: TagLib

  @spec get_tag!(non_neg_integer()) :: Tag.t()
  defdelegate get_tag!(tag_id), to: TagLib

  @spec get_tag(non_neg_integer()) :: Tag.t() | nil
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
  defdelegate change_tag(tag, attrs), to: TagLib

  alias Teiserver.Microblog.{Post, PostLib}

  @spec list_posts() :: [Post]
  defdelegate list_posts(), to: PostLib

  @spec list_posts(list) :: [Post]
  defdelegate list_posts(args), to: PostLib

  @spec list_posts_using_preferences(UserPreference.t() | nil, list) :: [Post]
  defdelegate list_posts_using_preferences(preference, args), to: PostLib

  @spec get_post!(non_neg_integer()) :: Post.t()
  defdelegate get_post!(post_id), to: PostLib

  @spec get_post!(non_neg_integer, list) :: Post.t()
  defdelegate get_post!(post_id, args), to: PostLib

  @spec get_post(non_neg_integer()) :: Post.t() | nil
  defdelegate get_post(post_id), to: PostLib

  @spec get_post(non_neg_integer(), list) :: Post.t() | nil
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
  defdelegate change_post(post, attrs), to: PostLib

  @spec increment_post_view_count(non_neg_integer()) :: Ecto.Changeset
  defdelegate increment_post_view_count(post_id), to: PostLib

  alias Teiserver.Microblog.{PostTag, PostTagLib}

  @spec list_post_tags() :: [PostTag]
  defdelegate list_post_tags(), to: PostTagLib

  @spec list_post_tags(list) :: [PostTag]
  defdelegate list_post_tags(args), to: PostTagLib

  @spec get_post_tag!(non_neg_integer(), non_neg_integer()) :: PostTag.t()
  defdelegate get_post_tag!(post_id, tag_id), to: PostTagLib

  @spec get_post_tag(non_neg_integer(), non_neg_integer()) :: PostTag.t() | nil
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
  defdelegate change_post_tag(post_tag, attrs), to: PostTagLib

  @spec delete_post_tags(non_neg_integer(), [non_neg_integer()]) ::
          {:ok, PostTag} | {:error, Ecto.Changeset}
  defdelegate delete_post_tags(post_id, tag_ids), to: PostTagLib

  alias Teiserver.Microblog.{UserPreference, UserPreferenceLib}

  @spec list_user_preferences() :: [UserPreference]
  defdelegate list_user_preferences(), to: UserPreferenceLib

  @spec list_user_preferences(list) :: [UserPreference]
  defdelegate list_user_preferences(args), to: UserPreferenceLib

  @spec get_user_preference!(non_neg_integer()) :: UserPreference.t()
  defdelegate get_user_preference!(user_preference_id), to: UserPreferenceLib

  @spec get_user_preference!(non_neg_integer, list) :: UserPreference.t()
  defdelegate get_user_preference!(user_preference_id, args), to: UserPreferenceLib

  @spec get_user_preference(non_neg_integer()) :: UserPreference.t() | nil
  defdelegate get_user_preference(user_preference_id), to: UserPreferenceLib

  @spec get_user_preference(non_neg_integer(), list) :: UserPreference.t() | nil
  defdelegate get_user_preference(user_preference_id, args), to: UserPreferenceLib

  @spec create_user_preference() :: {:ok, UserPreference} | {:error, Ecto.Changeset}
  defdelegate create_user_preference(), to: UserPreferenceLib

  @spec create_user_preference(map) :: {:ok, UserPreference} | {:error, Ecto.Changeset}
  defdelegate create_user_preference(attrs), to: UserPreferenceLib

  @spec update_user_preference(UserPreference, map) ::
          {:ok, UserPreference} | {:error, Ecto.Changeset}
  defdelegate update_user_preference(user_preference, attrs), to: UserPreferenceLib

  @spec delete_user_preference(UserPreference) :: {:ok, UserPreference} | {:error, Ecto.Changeset}
  defdelegate delete_user_preference(user_preference), to: UserPreferenceLib

  @spec change_user_preference(UserPreference) :: Ecto.Changeset
  defdelegate change_user_preference(user_preference), to: UserPreferenceLib

  @spec change_user_preference(UserPreference, map) :: Ecto.Changeset
  defdelegate change_user_preference(user_preference, attrs), to: UserPreferenceLib

  alias Teiserver.Microblog.{PollResponse, PollResponseLib}

  @spec list_poll_responses() :: [PollResponse]
  defdelegate list_poll_responses(), to: PollResponseLib

  @spec list_poll_responses(list) :: [PollResponse]
  defdelegate list_poll_responses(args), to: PollResponseLib

  @spec get_poll_response(Teiserver.user_id(), Post.id()) :: PollResponse.t() | nil
  defdelegate get_poll_response(user_id, post_id), to: PollResponseLib

  @spec create_poll_response() :: {:ok, PollResponse} | {:error, Ecto.Changeset}
  defdelegate create_poll_response(), to: PollResponseLib

  @spec create_poll_response(map) :: {:ok, PollResponse} | {:error, Ecto.Changeset}
  defdelegate create_poll_response(attrs), to: PollResponseLib

  @spec update_poll_response(PollResponse, map) :: {:ok, PollResponse} | {:error, Ecto.Changeset}
  defdelegate update_poll_response(poll_response, attrs), to: PollResponseLib

  @spec delete_poll_response(PollResponse) :: {:ok, PollResponse} | {:error, Ecto.Changeset}
  defdelegate delete_poll_response(poll_response), to: PollResponseLib

  @spec change_poll_response(PollResponse) :: Ecto.Changeset
  defdelegate change_poll_response(poll_response), to: PollResponseLib

  @spec change_poll_response(PollResponse, map) :: Ecto.Changeset
  defdelegate change_poll_response(poll_response, attrs), to: PollResponseLib
end
