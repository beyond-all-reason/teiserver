defmodule Teiserver.Microblog.PostTagQueries do
  @moduledoc false
  use TeiserverWeb, :queries
  alias Teiserver.Microblog.PostTag

  # Queries
  @spec query_post_tags(list) :: Ecto.Query.t()
  def query_post_tags(args) do
    query = from(post_tags in PostTag)

    query
    |> do_where(id: args[:id])
    |> do_where(args[:where])
    |> query_select(args[:select])
  end

  @spec do_where(Ecto.Query.t(), list | map | nil) :: Ecto.Query.t()
  defp do_where(query, nil), do: query

  defp do_where(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _where(query_acc, key, value)
    end)
  end

  @spec _where(Ecto.Query.t(), atom(), any()) :: Ecto.Query.t()
  defp _where(query, _, ""), do: query
  defp _where(query, _, nil), do: query

  defp _where(query, :post_id, post_id) do
    from post_tags in query,
      where: post_tags.post_id == ^post_id
  end

  defp _where(query, :post_id_in, post_ids) when is_list(post_ids) do
    from post_tags in query,
      where: post_tags.post_id in ^post_ids
  end

  defp _where(query, :tag_id, tag_id) do
    from post_tags in query,
      where: post_tags.tag_id == ^tag_id
  end

  defp _where(query, :tag_id_in, tag_ids) when is_list(tag_ids) do
    from post_tags in query,
      where: post_tags.tag_id in ^tag_ids
  end
end
