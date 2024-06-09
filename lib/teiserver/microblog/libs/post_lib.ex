defmodule Teiserver.Microblog.PostLib do
  @moduledoc false
  use TeiserverWeb, :library_newform
  alias Teiserver.Microblog.{Post, PostQueries, UserPreference}
  alias Phoenix.PubSub

  # Functions
  @spec icon :: String.t()
  def icon, do: "fa-solid fa-envelope"

  @spec colours :: atom
  def colours, do: :primary

  @doc """
  Returns the list of posts.

  ## Examples

      iex> list_posts()
      [%Post{}, ...]

  """
  @spec list_posts(list) :: [Post]
  def list_posts(args \\ []) do
    args
    |> PostQueries.query_posts()
    |> Repo.all()
  end

  @doc """
  Returns the list of posts.

  ## Examples

      iex> list_posts()
      [%Post{}, ...]

  """
  @spec list_posts_using_preferences(UserPreference.t() | nil, list) :: [Post]
  def list_posts_using_preferences(up), do: list_posts_using_preferences(up, [])

  def list_posts_using_preferences(nil, args) do
    list_posts(args)
  end

  def list_posts_using_preferences(user_preference, args) do
    extra_where = [
      enabled_tags: user_preference.enabled_tags,
      disabled_tags: user_preference.disabled_tags

      # poster_id_in: [],
      # poster_id_not_in: []
    ]

    (args ++ [where: extra_where])
    |> PostQueries.query_posts()
    |> Repo.all()
  end

  @doc """
  Gets a single post.

  Raises `Ecto.NoResultsError` if the Post does not exist.

  ## Examples

      iex> get_post!(123)
      %Post{}

      iex> get_post!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_post!(non_neg_integer()) :: Post.t()
  def get_post!(post_id) do
    [id: post_id]
    |> PostQueries.query_posts()
    |> Repo.one!()
  end

  @spec get_post!(non_neg_integer(), list) :: Post.t()
  def get_post!(post_id, args) do
    ([id: post_id] ++ args)
    |> PostQueries.query_posts()
    |> Repo.one!()
  end

  @spec get_post(non_neg_integer()) :: Post.t() | nil
  def get_post(post_id) do
    [id: post_id]
    |> PostQueries.query_posts()
    |> Repo.one()
  end

  @spec get_post(non_neg_integer(), list) :: Post.t() | nil
  def get_post(post_id, args) do
    ([id: post_id] ++ args)
    |> PostQueries.query_posts()
    |> Repo.one()
  end

  @doc """
  Creates a post.

  ## Examples

      iex> create_post(%{field: value})
      {:ok, %Post{}}

      iex> create_post(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_post(attrs \\ %{}) do
    %Post{}
    |> Post.changeset(attrs)
    |> Repo.insert()
    |> broadcast_create_post
  end

  defp broadcast_create_post({:ok, %Post{} = post}) do
    spawn(fn ->
      # We sleep this because sometimes the message is seen fast enough the database doesn't
      # show as having the new data (row lock maybe?)
      :timer.sleep(1000)

      PubSub.broadcast(
        Teiserver.PubSub,
        "microblog_posts",
        %{
          channel: "microblog_posts",
          event: :post_created,
          post: post
        }
      )
    end)

    {:ok, post}
  end

  defp broadcast_create_post(value), do: value

  @doc """
  Updates a post.

  ## Examples

      iex> update_post(post, %{field: new_value})
      {:ok, %Post{}}

      iex> update_post(post, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_post(%Post{} = post, attrs) do
    post
    |> Post.changeset(attrs)
    |> Repo.update()
    |> broadcast_update_post
  end

  defp broadcast_update_post({:ok, %Post{} = post}) do
    spawn(fn ->
      # We sleep this because sometimes the message is seen fast enough the database doesn't
      # show as having the new data (row lock maybe?)
      :timer.sleep(1000)

      PubSub.broadcast(
        Teiserver.PubSub,
        "microblog_posts",
        %{
          channel: "microblog_posts",
          event: :post_updated,
          post: post
        }
      )
    end)

    {:ok, post}
  end

  defp broadcast_update_post(value), do: value

  @doc """
  Deletes a post.

  ## Examples

      iex> delete_post(post)
      {:ok, %Post{}}

      iex> delete_post(post)
      {:error, %Ecto.Changeset{}}

  """
  def delete_post(%Post{} = post) do
    query = "DELETE FROM microblog_post_tags WHERE post_id = $1;"
    {:ok, _} = Ecto.Adapters.SQL.query(Repo, query, [post.id])

    Repo.delete(post)
    |> broadcast_delete_post
  end

  defp broadcast_delete_post({:ok, %Post{} = post}) do
    PubSub.broadcast(
      Teiserver.PubSub,
      "microblog_posts",
      %{
        channel: "microblog_posts",
        event: :post_deleted,
        post: post
      }
    )

    {:ok, post}
  end

  defp broadcast_delete_post(value), do: value

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking post changes.

  ## Examples

      iex> change_post(post)
      %Ecto.Changeset{data: %Post{}}

  """
  def change_post(%Post{} = post, attrs \\ %{}) do
    Post.changeset(post, attrs)
  end

  @spec increment_post_view_count(non_neg_integer()) :: Ecto.Changeset
  def increment_post_view_count(post_id) when is_integer(post_id) do
    query = "UPDATE microblog_posts SET view_count = view_count + 1 WHERE id = $1;"
    {:ok, _} = Ecto.Adapters.SQL.query(Repo, query, [post_id])
  end
end
