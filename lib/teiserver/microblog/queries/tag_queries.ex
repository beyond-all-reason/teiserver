defmodule Teiserver.Microblog.TagQueries do
  @moduledoc false
  use TeiserverWeb, :queries
  alias Teiserver.Microblog.Tag

  # Queries
  @spec query_tags(list) :: Ecto.Query.t()
  def query_tags(args) do
    query = from(tags in Tag)

    query
    |> do_where(id: args[:id])
    |> do_where(args[:where])
    |> do_order_by(args[:order_by])
    |> query_select(args[:select])
    |> limit_query(args[:limit] || 50)
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

  defp _where(query, :id, id) do
    from tags in query,
      where: tags.id == ^id
  end

  defp _where(query, :id_in, ids) do
    from tags in query,
      where: tags.id in ^ids
  end

  defp _where(query, :title_like, title) do
    utitle = "%" <> title <> "%"

    from tags in query,
      where: ilike(tags.title, ^utitle)
  end

  @spec do_order_by(Ecto.Query.t(), list | nil) :: Ecto.Query.t()
  defp do_order_by(query, nil), do: query

  defp do_order_by(query, params) when is_list(params) do
    params
    |> Enum.reduce(query, fn key, query_acc ->
      _order_by(query_acc, key)
    end)
  end

  defp do_order_by(query, params) when is_bitstring(params), do: do_order_by(query, [params])

  defp _order_by(query, nil), do: query

  defp _order_by(query, "Name (A-Z)") do
    from tags in query,
      order_by: [asc: tags.name]
  end

  defp _order_by(query, "Name (Z-A)") do
    from tags in query,
      order_by: [desc: tags.name]
  end
end
