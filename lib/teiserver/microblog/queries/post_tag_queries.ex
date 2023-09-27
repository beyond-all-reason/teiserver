defmodule Teiserver.Microblog.PostTagQueries do
  @moduledoc false
  use CentralWeb, :queries
  alias Teiserver.Microblog.PostTag

  # Queries
  @spec query_post_tags(list) :: Ecto.Query.t()
  def query_post_tags(args) do
    query = from(post_tags in PostTag)

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
    from post_tags in query,
      where: post_tags.id == ^id
  end

  defp _where(query, :hash, hash) do
    from post_tags in query,
      where: post_tags.hash == ^hash
  end

  defp _where(query, :between, {start_date, end_date}) do
    from post_tags in query,
      where: between(post_tags.timestamp, ^start_date, ^end_date)
  end

  defp _where(query, :event_type_id, event_type_id) do
    from post_tags in query,
      where: post_tags.event_type_id == ^event_type_id
  end

  defp _where(query, :event_type_id_in, event_type_ids) do
    from post_tags in query,
      where: post_tags.event_type_id in ^event_type_ids
  end

  @spec do_order_by(Ecto.Query.t(), list | nil) :: Ecto.Query.t()
  defp do_order_by(query, nil), do: query
  defp do_order_by(query, params) do
    params
    |> Enum.reduce(query, fn key, query_acc ->
      _order_by(query_acc, key)
    end)
  end

  defp _order_by(query, nil), do: query

  defp _order_by(query, "Newest first") do
    from post_tags in query,
      order_by: [desc: post_tags.timestamp]
  end

  defp _order_by(query, "Oldest first") do
    from post_tags in query,
      order_by: [asc: post_tags.timestamp]
  end

  @spec do_preload(Ecto.Query.t(), List.t() | nil) :: Ecto.Query.t()
  defp do_preload(query, nil), do: query

  defp do_preload(query, preloads) do
    preloads
    |> Enum.reduce(query, fn key, query_acc ->
      _preload(query_acc, key)
    end)
  end

  defp _preload(query, :event_types) do
    from post_tags in query,
      left_join: event_types in assoc(post_tags, :event_type),
      preload: [event_type: event_types]
  end

  @spec get_post_tags_summary(list) :: map()
  def get_post_tags_summary(args) do
    query =
      from post_tags in PostTag,
        join: event_types in assoc(post_tags, :event_type),
        group_by: event_types.name,
        select: {event_types.name, count(post_tags.event_type_id)}

    query
    |> do_where(args)
    |> Repo.all()
    |> Map.new()
  end

  def get_aggregate_detail(event_type_id, key, start_datetime, end_datetime) do
    query = """
    SELECT (e.value ->> $1) AS key, COUNT(e.id)
      FROM telemetry_post_tags e
      WHERE e.event_type_id = $2
      AND e.timestamp BETWEEN $3 AND $4
      GROUP BY key
    """
    case Ecto.Adapters.SQL.query(Repo, query, [key, event_type_id, start_datetime, end_datetime]) do
      {:ok, results} ->
        results.rows
          |> Map.new(fn [key, value] ->
            {key, value}
          end)

      {a, b} ->
        raise "ERR: #{a}, #{b}"
    end
  end
end
