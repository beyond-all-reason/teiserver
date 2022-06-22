defmodule Teiserver.Telemetry.ServerEventLib do
  use CentralWeb, :library
  alias Teiserver.Telemetry.ServerEvent

  # Functions
  @spec colour :: atom
  def colour(), do: :info2

  @spec icon() :: String.t()
  def icon(), do: "fa-regular fa-server"

  # Queries
  @spec query_server_events() :: Ecto.Query.t
  def query_server_events do
    from server_events in ServerEvent
  end

  @spec search(Ecto.Query.t, Map.t | nil) :: Ecto.Query.t
  def search(query, nil), do: query
  def search(query, params) do
    params
    |> Enum.reduce(query, fn ({key, value}, query_acc) ->
      _search(query_acc, key, value)
    end)
  end

  @spec _search(Ecto.Query.t, Atom.t(), any()) :: Ecto.Query.t
  def _search(query, _, ""), do: query
  def _search(query, _, nil), do: query

  def _search(query, :user_id, user_id) do
    from server_events in query,
      where: server_events.user_id == ^user_id
  end

  def _search(query, :user_id_in, user_ids) do
    from server_events in query,
      where: server_events.user_id in ^user_ids
  end

  def _search(query, :id_list, id_list) do
    from server_events in query,
      where: server_events.id in ^id_list
  end

  def _search(query, :between, {start_date, end_date}) do
    from server_events in query,
      where: between(server_events.timestamp, ^start_date, ^end_date)
  end

  def _search(query, :event_type_id, event_type_id) do
    from server_events in query,
      where: server_events.event_type_id == ^event_type_id
  end

  def _search(query, :event_type_id_in, event_type_ids) do
    from server_events in query,
      where: server_events.event_type_id in ^event_type_ids
  end

  @spec order_by(Ecto.Query.t, String.t | nil) :: Ecto.Query.t
  def order_by(query, nil), do: query
  def order_by(query, "Name (A-Z)") do
    from server_events in query,
      order_by: [asc: server_events.name]
  end

  def order_by(query, "Name (Z-A)") do
    from server_events in query,
      order_by: [desc: server_events.name]
  end

  def order_by(query, "Newest first") do
    from server_events in query,
      order_by: [desc: server_events.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from server_events in query,
      order_by: [asc: server_events.inserted_at]
  end

  @spec preload(Ecto.Query.t, List.t | nil) :: Ecto.Query.t
  def preload(query, nil), do: query
  def preload(query, preloads) do
    query = if :event_type in preloads, do: _preload_event_types(query), else: query
    query = if :user in preloads, do: _preload_users(query), else: query
    query
  end

  @spec _preload_event_types(Ecto.Query.t) :: Ecto.Query.t
  def _preload_event_types(query) do
    from server_events in query,
      left_join: event_types in assoc(server_events, :event_type),
      preload: [event_type: event_types]
  end

  @spec _preload_event_types(Ecto.Query.t) :: Ecto.Query.t
  def _preload_users(query) do
    from server_events in query,
      left_join: users in assoc(server_events, :user),
      preload: [user: users]
  end
end
