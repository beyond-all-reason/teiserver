defmodule Teiserver.Telemetry.ComplexLobbyEventTypeQueries do
  @moduledoc false
  use TeiserverWeb, :queries
  alias Teiserver.Telemetry.ComplexLobbyEventType

  # Queries
  @spec query_complex_lobby_event_types(list) :: Ecto.Query.t()
  def query_complex_lobby_event_types(args) do
    query = from(complex_lobby_event_types in ComplexLobbyEventType)

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
    from complex_lobby_event_types in query,
      where: complex_lobby_event_types.id == ^id
  end

  defp _where(query, :id_in, id_list) do
    from complex_lobby_event_types in query,
      where: complex_lobby_event_types.id in ^id_list
  end

  defp _where(query, :name, name) do
    from complex_lobby_event_types in query,
      where: complex_lobby_event_types.name == ^name
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

  defp _order_by(query, "Name (A-Z)") do
    from complex_lobby_event_types in query,
      order_by: [asc: complex_lobby_event_types.name]
  end

  defp _order_by(query, "Name (Z-A)") do
    from complex_lobby_event_types in query,
      order_by: [desc: complex_lobby_event_types.name]
  end

  defp _order_by(query, "ID (Lowest first)") do
    from complex_lobby_event_types in query,
      order_by: [asc: complex_lobby_event_types.id]
  end

  defp _order_by(query, "ID (Highest first)") do
    from complex_lobby_event_types in query,
      order_by: [desc: complex_lobby_event_types.id]
  end

  @spec do_preload(Ecto.Query.t(), list() | nil) :: Ecto.Query.t()
  defp do_preload(query, nil), do: query

  defp do_preload(query, preloads) do
    preloads
    |> Enum.reduce(query, fn key, query_acc ->
      _preload(query_acc, key)
    end)
  end

  defp _preload(query, :complex_lobby_events) do
    from complex_lobby_event_types in query,
      join: complex_lobby_events in assoc(complex_lobby_event_types, :complex_lobby_events),
      preload: [complex_lobby_events: complex_lobby_events]
  end
end
