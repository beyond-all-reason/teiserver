defmodule Teiserver.Telemetry.UnauthEventLib do
  use CentralWeb, :library
  alias Teiserver.Telemetry.UnauthEvent

  # Functions
  @spec colours :: atom
  def colours(), do: :info2

  @spec icon() :: String.t()
  def icon(), do: "fa-regular fa-sliders-up"

  # Queries
  @spec query_unauth_events() :: Ecto.Query.t
  def query_unauth_events do
    from unauth_events in UnauthEvent
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

  def _search(query, :id, id) do
    from unauth_events in query,
      where: unauth_events.id == ^id
  end

  def _search(query, :id_list, id_list) do
    from unauth_events in query,
      where: unauth_events.id in ^id_list
  end

  def _search(query, :basic_search, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from unauth_events in query,
      where: (
            ilike(unauth_events.name, ^ref_like)
        )
  end

  def _search(query, :event_type_id, event_type_id) do
    from unauth_events in query,
      where: unauth_events.event_type_id == ^event_type_id
  end

  def _search(query, :between, {start_date, end_date}) do
    from unauth_events in query,
      where: between(unauth_events.timestamp, ^start_date, ^end_date)
  end

  @spec order_by(Ecto.Query.t, String.t | nil) :: Ecto.Query.t
  def order_by(query, nil), do: query
  def order_by(query, "Name (A-Z)") do
    from unauth_events in query,
      order_by: [asc: unauth_events.name]
  end

  def order_by(query, "Name (Z-A)") do
    from unauth_events in query,
      order_by: [desc: unauth_events.name]
  end

  def order_by(query, "Newest first") do
    from unauth_events in query,
      order_by: [desc: unauth_events.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from unauth_events in query,
      order_by: [asc: unauth_events.inserted_at]
  end

  @spec preload(Ecto.Query.t, List.t | nil) :: Ecto.Query.t
  def preload(query, nil), do: query
  def preload(query, preloads) do
    query = if :event_type in preloads, do: _preload_event_types(query), else: query
    query
  end

  def _preload_event_types(query) do
    from unauth_events in query,
      left_join: event_types in assoc(unauth_events, :event_type),
      preload: [event_type: event_types]
  end
end
