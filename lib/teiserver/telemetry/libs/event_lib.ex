defmodule Teiserver.Telemetry.EventLib do
  use CentralWeb, :library
  alias Teiserver.Telemetry.Event

  # Functions
  @spec icon :: String.t()
  def icon, do: "far fa-???"
  @spec colours :: {String.t(), String.t(), String.t()}
  def colours, do: Central.Helpers.StylingHelper.colours(:default)

  # Queries
  @spec query_events() :: Ecto.Query.t
  def query_events do
    from events in Event
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
    from events in query,
      where: events.id == ^id
  end

  def _search(query, :name, name) do
    from events in query,
      where: events.name == ^name
  end

  def _search(query, :id_list, id_list) do
    from events in query,
      where: events.id in ^id_list
  end

  def _search(query, :simple_search, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from events in query,
      where: (
            ilike(events.name, ^ref_like)
        )
  end

  @spec order_by(Ecto.Query.t, String.t | nil) :: Ecto.Query.t
  def order_by(query, nil), do: query
  def order_by(query, "Name (A-Z)") do
    from events in query,
      order_by: [asc: events.name]
  end

  def order_by(query, "Name (Z-A)") do
    from events in query,
      order_by: [desc: events.name]
  end

  def order_by(query, "Newest first") do
    from events in query,
      order_by: [desc: events.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from events in query,
      order_by: [asc: events.inserted_at]
  end

  @spec preload(Ecto.Query.t, List.t | nil) :: Ecto.Query.t
  def preload(query, nil), do: query
  def preload(query, _preloads) do
    # query = if :things in preloads, do: _preload_things(query), else: query
    query
  end

  # def _preload_things(query) do
  #   from events in query,
  #     left_join: things in assoc(events, :things),
  #     preload: [things: things]
  # end
end
