defmodule Teiserver.Polling.ResponseQueries do
  @moduledoc false
  use TeiserverWeb, :queries
  alias Teiserver.Polling.Response

  # Queries
  @spec query_responses(list) :: Ecto.Query.t()
  def query_responses(args) do
    query = from(responses in Response)

    query
    |> do_where([id: args[:id]])
    |> do_where(args[:where])
    |> do_preload(args[:preload])
    |> do_order_by(args[:order_by])
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

  @spec _where(Ecto.Query.t(), Atom.t(), any()) :: Ecto.Query.t()
  defp _where(query, _, ""), do: query
  defp _where(query, _, nil), do: query

  defp _where(query, :id, id) do
    from responses in query,
      where: responses.id == ^id
  end

  defp _where(query, :author_id, author_id) do
    from responses in query,
      where: responses.author_id == ^author_id
  end

  defp _where(query, :author_id_in, []), do: query
  defp _where(query, :author_id_in, author_ids) when is_list(author_ids) do
    from responses in query,
      where: responses.author_id in ^author_ids
  end

  defp _where(query, :author_id_not_in, []), do: query
  defp _where(query, :author_id_not_in, author_ids) when is_list(author_ids) do
    from responses in query,
      where: responses.author_id not in ^author_ids
  end

  defp _where(query, :name_like, name) do
    uname = "%" <> name <> "%"

    from responses in query,
      where: ilike(responses.name, ^uname)
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
    from responses in query,
      order_by: [asc: responses.name]
  end

  defp _order_by(query, "Name (Z-A)") do
    from responses in query,
      order_by: [desc: responses.name]
  end

  defp _order_by(query, "Newest first") do
    from responses in query,
      order_by: [desc: responses.inserted_at]
  end

  defp _order_by(query, "Oldest first") do
    from responses in query,
      order_by: [asc: responses.inserted_at]
  end

  @spec do_preload(Ecto.Query.t(), List.t() | nil) :: Ecto.Query.t()
  defp do_preload(query, nil), do: query

  defp do_preload(query, preloads) do
    preloads
    |> Enum.reduce(query, fn key, query_acc ->
      _preload(query_acc, key)
    end)
  end

  defp _preload(query, :author) do
    from responses in query,
      left_join: authors in assoc(responses, :author),
      preload: [author: authors]
  end
end
