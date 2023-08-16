defmodule Teiserver.Telemetry.ComplexMatchEventQueries do
  @moduledoc false
  use CentralWeb, :library
  alias Teiserver.Helper.QueryHelpers
  alias Teiserver.Telemetry.ComplexMatchEvent

  # Queries
  @spec query_complex_match_events(list) :: Ecto.Query.t()
  def query_complex_match_events(args) do
    query = from(complex_match_events in ComplexMatchEvent)

    query
    |> do_where([id: args[:id]])
    |> do_where(args[:where])
    |> do_preload(args[:preload])
    |> do_order_by(args[:order_by])
    |> QueryHelpers.select(args[:select])
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
    from complex_match_events in query,
      where: complex_match_events.id == ^id
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
      order_by: [desc: complex_match_events.updated_at]
  end

  defp _order_by(query, "Oldest first") do
    from complex_match_events in query,
      order_by: [asc: complex_match_events.updated_at]
  end

  @spec do_preload(Ecto.Query.t(), List.t() | nil) :: Ecto.Query.t()
  defp do_preload(query, nil), do: query

  defp do_preload(query, preloads) do
    preloads
    |> Enum.reduce(query, fn key, query_acc ->
      _preload(query_acc, key)
    end)
  end

  defp _preload(query, :users) do
    from complex_match_events in query,
      join: tos in assoc(complex_match_events, :to),
      preload: [to: tos],
      join: froms in assoc(complex_match_events, :from),
      preload: [from: froms]
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
end
