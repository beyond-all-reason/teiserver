defmodule Central.Communication.CommentLib do
  @moduledoc false
  use CentralWeb, :library
  alias Central.Communication.Comment

  @spec colours() :: atom
  def colours(), do: :info

  @spec icon() :: String.t()
  def icon(), do: "far fa-comment"

  # Queries
  @spec get_comments() :: Ecto.Query.t()
  def get_comments do
    from(comments in Comment)
  end

  @spec search(Ecto.Query.t(), map | nil) :: Ecto.Query.t()
  def search(query, nil), do: query

  def search(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _search(query_acc, key, value)
    end)
  end

  def _search(query, _, ""), do: query
  def _search(query, _, nil), do: query

  def _search(query, :id, id) do
    from comments in query,
      where: comments.id == ^id
  end

  def _search(query, :poster_name, poster_name) do
    from comments in query,
      where: comments.poster_name == ^poster_name
  end

  def _search(query, :id_list, id_list) do
    from comments in query,
      where: comments.id in ^id_list
  end

  def _search(query, :basic_search, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from comments in query,
      where: ilike(comments.poster_name, ^ref_like)
  end

  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, "Newest first") do
    from comments in query,
      order_by: [desc: comments.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from comments in query,
      order_by: [asc: comments.inserted_at]
  end

  @spec preload(Ecto.Query.t(), list | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, preloads) do
    query = if :poster in preloads, do: _preload_poster(query), else: query
    query = if :post in preloads, do: _preload_post(query), else: query
    query
  end

  def _preload_poster(query) do
    from comments in query,
      left_join: posters in assoc(comments, :poster),
      preload: [poster: posters]
  end

  def _preload_post(query) do
    from comments in query,
      left_join: posts in assoc(comments, :post),
      preload: [post: posts]
  end
end
