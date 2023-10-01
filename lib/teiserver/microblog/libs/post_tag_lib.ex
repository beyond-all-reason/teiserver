defmodule Teiserver.Microblog.PostTagLib do
  @moduledoc false
  use CentralWeb, :library_newform
  alias Teiserver.Microblog.{PostTag, PostTagQueries}

  @doc """
  Returns the list of post_tags.

  ## Examples

      iex> list_post_tags()
      [%PostTag{}, ...]

  """
  @spec list_post_tags(list) :: list
  def list_post_tags(args \\ []) do
    args
    |> PostTagQueries.query_post_tags()
    |> Repo.all()
  end

  @doc """
  Gets a single post_tag.

  Raises `Ecto.NoResultsError` if the PostTag does not exist.

  ## Examples

      iex> get_post_tag!(123)
      %PostTag{}

      iex> get_post_tag!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_post_tag!(non_neg_integer(), non_neg_integer()) :: PostTag.t
  def get_post_tag!(post_id, tag_id) do
    [post_id: post_id, tag_id: tag_id]
    |> PostTagQueries.query_post_tags()
    |> Repo.one!()
  end

  @spec get_post_tag(non_neg_integer(), non_neg_integer()) :: PostTag.t | nil
  def get_post_tag(post_id, tag_id) do
    [post_id: post_id, tag_id: tag_id]
    |> PostTagQueries.query_post_tags()
    |> Repo.one()
  end

  @doc """
  Creates a post_tag.

  ## Examples

      iex> create_post_tag(%{field: value})
      {:ok, %PostTag{}}

      iex> create_post_tag(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_post_tag(attrs \\ %{}) do
    %PostTag{}
    |> PostTag.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a post_tag.

  ## Examples

      iex> update_post_tag(post_tag, %{field: new_value})
      {:ok, %PostTag{}}

      iex> update_post_tag(post_tag, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_post_tag(%PostTag{} = post_tag, attrs) do
    post_tag
    |> PostTag.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a post_tag.

  ## Examples

      iex> delete_post_tag(post_tag)
      {:ok, %PostTag{}}

      iex> delete_post_tag(post_tag)
      {:error, %Ecto.Changeset{}}

  """
  def delete_post_tag(%PostTag{} = post_tag) do
    Repo.delete(post_tag)
  end

  @spec delete_post_tags(non_neg_integer(), [non_neg_integer()]) :: {:ok, PostTag} | {:error, Ecto.Changeset}
  def delete_post_tags(post_id, tag_ids) do
    query = "DELETE FROM microblog_post_tags WHERE post_id = $1 AND tag_id = ANY($2);"
    {:ok, _} = Ecto.Adapters.SQL.query(Repo, query, [post_id, tag_ids])
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking post_tag changes.

  ## Examples

      iex> change_post_tag(post_tag)
      %Ecto.Changeset{data: %PostTag{}}

  """
  def change_post_tag(%PostTag{} = post_tag, attrs \\ %{}) do
    PostTag.changeset(post_tag, attrs)
  end
end
