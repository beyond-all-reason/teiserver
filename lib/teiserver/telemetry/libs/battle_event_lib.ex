defmodule Teiserver.Telemetry.BattleEventLib do
  use CentralWeb, :library
  alias Teiserver.Telemetry.BattleEvent

  # Functions
  @spec icon :: String.t()
  def icon, do: "far fa-???"
  @spec colours :: {String.t(), String.t(), String.t()}
  def colours, do: Central.Helpers.StylingHelper.colours(:default)

  # Queries
  @spec query_battle_events() :: Ecto.Query.t
  def query_battle_events do
    from battle_events in BattleEvent
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
    from battle_events in query,
      where: battle_events.id == ^id
  end

  def _search(query, :name, name) do
    from battle_events in query,
      where: battle_events.name == ^name
  end

  def _search(query, :id_list, id_list) do
    from battle_events in query,
      where: battle_events.id in ^id_list
  end

  def _search(query, :simple_search, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from battle_events in query,
      where: (
            ilike(battle_events.name, ^ref_like)
        )
  end

  @spec order_by(Ecto.Query.t, String.t | nil) :: Ecto.Query.t
  def order_by(query, nil), do: query
  def order_by(query, "Name (A-Z)") do
    from battle_events in query,
      order_by: [asc: battle_events.name]
  end

  def order_by(query, "Name (Z-A)") do
    from battle_events in query,
      order_by: [desc: battle_events.name]
  end

  def order_by(query, "Newest first") do
    from battle_events in query,
      order_by: [desc: battle_events.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from battle_events in query,
      order_by: [asc: battle_events.inserted_at]
  end

  @spec preload(Ecto.Query.t, List.t | nil) :: Ecto.Query.t
  def preload(query, nil), do: query
  def preload(query, _preloads) do
    # query = if :things in preloads, do: _preload_things(query), else: query
    query
  end

  # def _preload_things(query) do
  #   from battle_events in query,
  #     left_join: things in assoc(battle_events, :things),
  #     preload: [things: things]
  # end
end
