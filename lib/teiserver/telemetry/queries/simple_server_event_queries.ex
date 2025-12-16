defmodule Teiserver.Telemetry.SimpleServerEventQueries do
  @moduledoc false
  use TeiserverWeb, :queries
  alias Teiserver.Telemetry.SimpleServerEvent

  # Queries
  @spec query_simple_server_events(list) :: Ecto.Query.t()
  def query_simple_server_events(args) do
    query = from(simple_server_events in SimpleServerEvent)

    query
    |> do_where(id: args[:id])
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

  defp _where(query, :id, id) do
    from simple_server_events in query,
      where: simple_server_events.id == ^id
  end

  defp _where(query, :user_id, userid) do
    from simple_server_events in query,
      where: simple_server_events.user_id == ^userid
  end

  defp _where(query, :between, {start_date, end_date}) do
    from simple_server_events in query,
      where: between(simple_server_events.timestamp, ^start_date, ^end_date)
  end

  defp _where(query, :event_type_id, event_type_id) do
    from simple_server_events in query,
      where: simple_server_events.event_type_id == ^event_type_id
  end

  defp _where(query, :event_type_id_in, event_type_ids) do
    from simple_server_events in query,
      where: simple_server_events.event_type_id in ^event_type_ids
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
    from simple_server_events in query,
      order_by: [desc: simple_server_events.timestamp]
  end

  defp _order_by(query, "Oldest first") do
    from simple_server_events in query,
      order_by: [asc: simple_server_events.timestamp]
  end

  @spec do_preload(Ecto.Query.t(), list() | nil) :: Ecto.Query.t()
  defp do_preload(query, nil), do: query

  defp do_preload(query, preloads) do
    preloads
    |> Enum.reduce(query, fn key, query_acc ->
      _preload(query_acc, key)
    end)
  end

  defp _preload(query, :users) do
    from simple_server_events in query,
      left_join: users in assoc(simple_server_events, :user),
      preload: [user: users]
  end

  defp _preload(query, :event_types) do
    from simple_server_events in query,
      left_join: event_types in assoc(simple_server_events, :event_type),
      preload: [event_type: event_types]
  end

  @spec get_simple_server_events_summary(list) :: map()
  def get_simple_server_events_summary(args) do
    query =
      from simple_server_events in SimpleServerEvent,
        join: event_types in assoc(simple_server_events, :event_type),
        group_by: event_types.name,
        select: {event_types.name, count(simple_server_events.event_type_id)}

    query
    |> do_where(args)
    |> Repo.all()
    |> Map.new()
  end

  def get_aggregate_detail(event_type_id, start_datetime, end_datetime) do
    query = """
    SELECT e.user_id, COUNT(e.id)
      FROM telemetry_simple_server_events e
      WHERE e.event_type_id = $1
      AND e.timestamp BETWEEN $2 AND $3
      GROUP BY e.user_id
    """

    case Ecto.Adapters.SQL.query(Repo, query, [event_type_id, start_datetime, end_datetime]) do
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
