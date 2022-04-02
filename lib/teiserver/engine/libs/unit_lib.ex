defmodule Teiserver.Engine.UnitLib do
  use CentralWeb, :library
  alias Teiserver.Engine.Unit

  # Functions
  @spec icon :: String.t()
  def icon, do: "fa-regular fa-drone-front"

  @spec colours :: atom
  def colours, do: :default

  @spec make_favourite(Map.t()) :: Map.t()
  def make_favourite(unit) do
    %{
      type_colour: StylingHelper.colours(colours()) |> elem(0),
      type_icon: icon(),

      item_id: unit.id,
      item_type: "teiserver_engine_unit",
      item_colour: colours() |> elem(0),
      item_icon: Teiserver.Engine.UnitLib.icon(),
      item_label: "#{unit.name}",

      url: "/engine/units/#{unit.id}"
    }
  end

  # Queries
  @spec query_units() :: Ecto.Query.t
  def query_units do
    from units in Unit
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
    from units in query,
      where: units.id == ^id
  end

  def _search(query, :name, name) do
    from units in query,
      where: units.name == ^name
  end

  def _search(query, :id_list, id_list) do
    from units in query,
      where: units.id in ^id_list
  end

  def _search(query, :basic_search, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from units in query,
      where: (
            ilike(units.name, ^ref_like)
        )
  end

  @spec order_by(Ecto.Query.t, String.t | nil) :: Ecto.Query.t
  def order_by(query, nil), do: query
  def order_by(query, "Name (A-Z)") do
    from units in query,
      order_by: [asc: units.name]
  end

  def order_by(query, "Name (Z-A)") do
    from units in query,
      order_by: [desc: units.name]
  end

  def order_by(query, "Newest first") do
    from units in query,
      order_by: [desc: units.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from units in query,
      order_by: [asc: units.inserted_at]
  end

  @spec preload(Ecto.Query.t, List.t | nil) :: Ecto.Query.t
  def preload(query, nil), do: query
  def preload(query, _preloads) do
    # query = if :things in preloads, do: _preload_things(query), else: query
    query
  end

  # def _preload_things(query) do
  #   from units in query,
  #     left_join: things in assoc(units, :things),
  #     preload: [things: things]
  # end
end
