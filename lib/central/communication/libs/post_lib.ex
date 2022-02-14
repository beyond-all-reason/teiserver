defmodule Central.Communication.PostLib do
  @moduledoc false
  use CentralWeb, :library
  alias Central.Communication.Post

  @spec colours() :: atom
  def colours(), do: :primary

  @spec icon() :: String.t()
  def icon(), do: "far fa-file-alt"

  # Queries
  @spec get_posts() :: Ecto.Query.t()
  def get_posts do
    from(posts in Post)
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
    from posts in query,
      where: posts.id == ^id
  end

  def _search(query, :title, title) do
    from posts in query,
      where: posts.title == ^title
  end

  def _search(query, :visible, visible) do
    from posts in query,
      where: posts.visible == ^visible
  end

  def _search(query, :tag, tag) do
    from posts in query,
      where: ^tag in posts.tags
  end

  def _search(query, :category_name, category_name) do
    from posts in query,
      inner_join: categories in assoc(posts, :category),
      where: categories.name == ^category_name
  end

  def _search(query, :category_id, category_id) do
    from posts in query,
      where: posts.category_id == ^category_id
  end

  def _search(query, :url_slug, url_slug) do
    from posts in query,
      where: posts.url_slug == ^url_slug
  end

  def _search(query, :id_list, id_list) do
    from posts in query,
      where: posts.id in ^id_list
  end

  def _search(query, :basic_search, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from posts in query,
      where: ilike(posts.title, ^ref_like)
  end

  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, "Newest first") do
    from posts in query,
      order_by: [desc: posts.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from posts in query,
      order_by: [asc: posts.inserted_at]
  end

  @spec preload(Ecto.Query.t(), list | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, preloads) do
    query = if :category in preloads, do: _preload_category(query), else: query
    query = if :poster in preloads, do: _preload_poster(query), else: query
    query = if :comments in preloads, do: _preload_comments(query), else: query

    query =
      if :comments_with_posters in preloads,
        do: _preload_comments_with_posters(query),
        else: query

    query
  end

  def _preload_category(query) do
    from posts in query,
      join: category in assoc(posts, :category),
      preload: [category: category]
  end

  def _preload_poster(query) do
    from posts in query,
      join: poster in assoc(posts, :poster),
      preload: [poster: poster]
  end

  def _preload_comments(query) do
    from posts in query,
      left_join: comments in assoc(posts, :comments),
      preload: [comments: comments]
  end

  def _preload_comments_with_posters(query) do
    from systems in query,
      left_join: comments in assoc(systems, :comments),
      left_join: posters in assoc(comments, :poster),
      order_by: [asc: comments.inserted_at],
      preload: [comments: {comments, poster: posters}]
  end

  def get_key(url_slug) do
    :crypto.hash(:md5, url_slug)
    |> Base.encode16()
  end
end
