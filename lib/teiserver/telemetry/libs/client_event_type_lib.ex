defmodule Teiserver.Telemetry.ClientEventTypeLib do
  @moduledoc false
  use CentralWeb, :library
  alias Teiserver.Helper.QueryHelpers
  alias Teiserver.Telemetry.ClientEventType

  # Helper function
  @spec get_or_add_client_event_type(String.t()) :: non_neg_integer()
  def get_or_add_client_event_type(name) do
    name = String.trim(name)

    Central.cache_get_or_store(:telemetry_client_event_types_cache, name, fn ->
      query = query_client_event_types(where: [name: name], select: [:id], order_by: ["ID (Lowest first)"])
      case Repo.all(query) do
        [] ->
          {:ok, event_type} =
            %ClientEventType{}
            |> ClientEventType.changeset(%{name: name})
            |> Repo.insert()

          event_type.id

        [%{id: id} | _] ->
          id
      end
    end)
  end

  # Queries
  @spec query_client_event_types(list) :: Ecto.Query.t()
  def query_client_event_types(args) do
    query = from(client_event_types in ClientEventType)

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
    from client_event_types in query,
      where: client_event_types.id == ^id
  end

  defp _where(query, :id_in, id_list) do
    from client_event_types in query,
      where: client_event_types.id in ^id_list
  end

  defp _where(query, :name, name) do
    from client_event_types in query,
      where: client_event_types.name == ^name
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
    from client_event_types in query,
      order_by: [asc: client_event_types.name]
  end

  defp _order_by(query, "Name (Z-A)") do
    from client_event_types in query,
      order_by: [desc: client_event_types.name]
  end

  defp _order_by(query, "ID (Lowest first)") do
    from client_event_types in query,
      order_by: [asc: client_event_types.id]
  end

  defp _order_by(query, "ID (Highest first)") do
    from client_event_types in query,
      order_by: [desc: client_event_types.id]
  end

  @spec do_preload(Ecto.Query.t(), List.t() | nil) :: Ecto.Query.t()
  defp do_preload(query, nil), do: query

  defp do_preload(query, preloads) do
    preloads
    |> Enum.reduce(query, fn key, query_acc ->
      _preload(query_acc, key)
    end)
  end

  defp _preload(query, :client_events) do
    from client_event_types in query,
      join: client_events in assoc(client_event_types, :client_events),
      preload: [client_events: client_events]
  end
end
