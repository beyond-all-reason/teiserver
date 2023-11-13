defmodule Teiserver.Polling.SurveyQueries do
  @moduledoc false
  use TeiserverWeb, :queries
  alias Teiserver.Polling.Survey

  # Queries
  @spec query_surveys(list) :: Ecto.Query.t()
  def query_surveys(args) do
    query = from(surveys in Survey)

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
    from surveys in query,
      where: surveys.id == ^id
  end

  defp _where(query, :author_id, author_id) do
    from surveys in query,
      where: surveys.author_id == ^author_id
  end

  defp _where(query, :author_id_in, []), do: query
  defp _where(query, :author_id_in, author_ids) when is_list(author_ids) do
    from surveys in query,
      where: surveys.author_id in ^author_ids
  end

  defp _where(query, :author_id_not_in, []), do: query
  defp _where(query, :author_id_not_in, author_ids) when is_list(author_ids) do
    from surveys in query,
      where: surveys.author_id not in ^author_ids
  end

  defp _where(query, :name_like, name) do
    uname = "%" <> name <> "%"

    from surveys in query,
      where: ilike(surveys.name, ^uname)
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
    from surveys in query,
      order_by: [asc: surveys.name]
  end

  defp _order_by(query, "Name (Z-A)") do
    from surveys in query,
      order_by: [desc: surveys.name]
  end

  defp _order_by(query, "Newest first") do
    from surveys in query,
      order_by: [desc: surveys.inserted_at]
  end

  defp _order_by(query, "Oldest first") do
    from surveys in query,
      order_by: [asc: surveys.inserted_at]
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
    from surveys in query,
      left_join: authors in assoc(surveys, :author),
      preload: [author: authors]
  end

  # This just grabs the tags
  defp _preload(query, :questions) do
    from surveys in query,
      left_join: questions in assoc(surveys, :questions),
      preload: [questions: questions]
  end
end
