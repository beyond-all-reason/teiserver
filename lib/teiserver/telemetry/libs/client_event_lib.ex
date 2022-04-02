defmodule Teiserver.Telemetry.ClientEventLib do
  use CentralWeb, :library
  alias Teiserver.Telemetry.ClientEvent

  # Functions
  @spec colour :: atom
  def colour(), do: :info2

  @spec icon() :: String.t()
  def icon(), do: "fa-regular fa-sliders-up"

  # Queries
  @spec query_client_events() :: Ecto.Query.t
  def query_client_events do
    from client_events in ClientEvent
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
    from client_events in query,
      where: client_events.user_id == ^user_id
  end

  def _search(query, :id_list, id_list) do
    from client_events in query,
      where: client_events.id in ^id_list
  end

  def _search(query, :between, {start_date, end_date}) do
    from client_events in query,
      where: between(client_events.timestamp, ^start_date, ^end_date)
  end

  def _search(query, :event_type_id, event_type_id) do
    from client_events in query,
      where: client_events.event_type_id == ^event_type_id
  end

  def _search(query, :basic_search, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from client_events in query,
      where: (
            ilike(client_events.name, ^ref_like)
        )
  end

  @spec order_by(Ecto.Query.t, String.t | nil) :: Ecto.Query.t
  def order_by(query, nil), do: query
  def order_by(query, "Name (A-Z)") do
    from client_events in query,
      order_by: [asc: client_events.name]
  end

  def order_by(query, "Name (Z-A)") do
    from client_events in query,
      order_by: [desc: client_events.name]
  end

  def order_by(query, "Newest first") do
    from client_events in query,
      order_by: [desc: client_events.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from client_events in query,
      order_by: [asc: client_events.inserted_at]
  end

  @spec preload(Ecto.Query.t, List.t | nil) :: Ecto.Query.t
  def preload(query, nil), do: query
  def preload(query, preloads) do
    query = if :event_type in preloads, do: _preload_event_types(query), else: query
    query = if :user in preloads, do: _preload_users(query), else: query
    query
  end

  def _preload_event_types(query) do
    from client_events in query,
      left_join: event_types in assoc(client_events, :event_type),
      preload: [event_type: event_types]
  end

  def _preload_users(query) do
    from client_events in query,
      left_join: users in assoc(client_events, :user),
      preload: [user: users]
  end
end
