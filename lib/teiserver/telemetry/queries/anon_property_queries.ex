defmodule Teiserver.Telemetry.AnonPropertyQueries do
  @moduledoc false
  use TeiserverWeb, :queries
  alias Teiserver.Telemetry.AnonProperty

  # Queries
  @spec query_anon_properties(list) :: Ecto.Query.t()
  def query_anon_properties(args) do
    query = from(anon_properties in AnonProperty)

    query
    |> do_where(hash: args[:hash])
    |> do_where(property_type_id: args[:property_type_id])
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

  @spec _where(Ecto.Query.t(), atom(), any()) :: Ecto.Query.t()
  defp _where(query, _, ""), do: query
  defp _where(query, _, nil), do: query

  defp _where(query, :hash, hash) do
    from anon_properties in query,
      where: anon_properties.hash == ^hash
  end

  defp _where(query, :property_type_id, property_type_id) do
    from anon_properties in query,
      where: anon_properties.property_type_id == ^property_type_id
  end

  defp _where(query, :between, {start_date, end_date}) do
    from anon_properties in query,
      where: between(anon_properties.last_updated, ^start_date, ^end_date)
  end

  defp _where(query, :event_type_id, event_type_id) do
    from anon_properties in query,
      where: anon_properties.event_type_id == ^event_type_id
  end

  defp _where(query, :event_type_id_in, event_type_ids) do
    from anon_properties in query,
      where: anon_properties.event_type_id in ^event_type_ids
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
    from anon_properties in query,
      order_by: [desc: anon_properties.timestamp]
  end

  defp _order_by(query, "Oldest first") do
    from anon_properties in query,
      order_by: [asc: anon_properties.timestamp]
  end

  @spec do_preload(Ecto.Query.t(), List.t() | nil) :: Ecto.Query.t()
  defp do_preload(query, nil), do: query

  defp do_preload(query, preloads) do
    preloads
    |> Enum.reduce(query, fn key, query_acc ->
      _preload(query_acc, key)
    end)
  end

  def _preload(query, :property_type) do
    from anon_properties in query,
      left_join: property_types in assoc(anon_properties, :property_type),
      preload: [property_type: property_types]
  end

  @spec get_anon_properties_summary(list) :: map()
  def get_anon_properties_summary(args) do
    query =
      from anon_properties in AnonProperty,
        join: property_types in assoc(anon_properties, :property_type),
        group_by: property_types.name,
        select: {property_types.name, count(anon_properties.property_type_id)}

    query
    |> do_where(args)
    |> Repo.all()
    |> Map.new()
  end

  def get_aggregate_detail(property_type_id, start_datetime, end_datetime) do
    query = """
    SELECT p.value AS value, COUNT(p.value)
      FROM telemetry_anon_properties p
      WHERE p.property_type_id = $1
      AND p.last_updated BETWEEN $2 AND $3
      GROUP BY value
    """

    case Ecto.Adapters.SQL.query(Repo, query, [property_type_id, start_datetime, end_datetime]) do
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
