defmodule Teiserver.Telemetry.ComplexMatchEventQueries do
  @moduledoc false
  use TeiserverWeb, :queries
  alias Teiserver.Telemetry.ComplexMatchEvent

  # Queries
  @spec query_complex_match_events(list) :: Ecto.Query.t()
  def query_complex_match_events(args) do
    query = from(complex_match_events in ComplexMatchEvent)

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
    from complex_match_events in query,
      where: complex_match_events.id == ^id
  end

  defp _where(query, :user_id, userid) do
    from complex_match_events in query,
      where: complex_match_events.user_id == ^userid
  end

  defp _where(query, :match_id, match_id) do
    from complex_match_events in query,
      where: complex_match_events.match_id == ^match_id
  end

  defp _where(query, :between, {start_date, end_date}) do
    from complex_match_events in query,
      left_join: matches in assoc(complex_match_events, :match),
      where: between(matches.started, ^start_date, ^end_date)
  end

  defp _where(query, :event_type_id, event_type_id) do
    from complex_match_events in query,
      where: complex_match_events.event_type_id == ^event_type_id
  end

  defp _where(query, :event_type_id_in, event_type_ids) do
    from complex_match_events in query,
      where: complex_match_events.event_type_id in ^event_type_ids
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
    from complex_match_events in query,
      order_by: [desc: complex_match_events.timestamp]
  end

  defp _order_by(query, "Oldest first") do
    from complex_match_events in query,
      order_by: [asc: complex_match_events.timestamp]
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
    from complex_match_events in query,
      left_join: users in assoc(complex_match_events, :user),
      preload: [user: users]
  end

  defp _preload(query, :event_types) do
    from complex_match_events in query,
      left_join: event_types in assoc(complex_match_events, :event_type),
      preload: [event_type: event_types]
  end

  @spec get_complex_match_events_summary(list) :: map()
  def get_complex_match_events_summary(args) do
    query =
      from complex_match_events in ComplexMatchEvent,
        join: event_types in assoc(complex_match_events, :event_type),
        group_by: event_types.name,
        select: {event_types.name, count(complex_match_events.event_type_id)}

    query
    |> do_where(args)
    |> Repo.all()
    |> Map.new()
  end

  def get_aggregate_detail(event_type_id, key, start_datetime, end_datetime, limit \\ 50) do
    events_query = """
    SELECT
      e.value AS event,
      e.match_id AS match,
      e.game_time AS game_time
    FROM telemetry_complex_match_events e
    WHERE e.event_type_id = $1
      AND e.timestamp BETWEEN $2 AND $3
    LIMIT $4
    """

    aggregates_query = """
    SELECT
        value->>$1 AS value,
        COUNT(*) AS count
    FROM
        telemetry_complex_match_events e
    WHERE
      e.event_type_id = $2 AND e.timestamp BETWEEN $3 AND $4
    GROUP BY
        value->>$1
    LIMIT $5
    """

    case Ecto.Adapters.SQL.query(Repo, events_query, [
           event_type_id,
           start_datetime,
           end_datetime,
           limit
         ]) do
      {:ok, results} ->
        events =
          Enum.map(results.rows, fn [event, match_id, game_time] ->
            event
            |> Map.put("match", match_id)
            |> Map.put("game_time", game_time)
          end)

        case Ecto.Adapters.SQL.query(Repo, aggregates_query, [
               key,
               event_type_id,
               start_datetime,
               end_datetime,
               limit
             ]) do
          {:ok, agg_results} ->
            aggregates =
              Enum.map(agg_results.rows, fn [value, count] ->
                %{value: value, count: count}
              end)

            %{
              events: events,
              aggregates: aggregates
            }

          {:error, reason} ->
            raise "Complex match event aggregates query error: #{reason}"
        end

      {:error, reason} ->
        raise "Complex match event query error: #{reason}"
    end
  end
end
