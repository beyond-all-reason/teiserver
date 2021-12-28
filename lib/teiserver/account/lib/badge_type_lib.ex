defmodule Teiserver.Account.BadgeTypeLib do
  use CentralWeb, :library
  alias Teiserver.Account.BadgeType

  # Functions
  @spec icon :: String.t()
  def icon, do: "far fa-certificate"

  @spec colours :: {String.t(), String.t(), String.t()}
  def colours, do: Central.Helpers.StylingHelper.colours(:warning2)

  @spec purpose_list() :: [String.t()]
  def purpose_list(), do: ["Accolade"]

  @spec make_favourite(Map.t()) :: Map.t()
  def make_favourite(badge_type) do
    %{
      type_colour: colours() |> elem(0),
      type_icon: icon(),

      item_id: badge_type.id,
      item_type: "teiserver_account_badge_type",
      item_colour: badge_type.colour,
      item_icon: badge_type.icon,
      item_label: "#{badge_type.name}",

      url: "/account/badge_types/#{badge_type.id}"
    }
  end

  # Queries
  @spec query_badge_types() :: Ecto.Query.t
  def query_badge_types do
    from badge_types in BadgeType
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
    from badge_types in query,
      where: badge_types.id == ^id
  end

  def _search(query, :name, name) do
    from badge_types in query,
      where: badge_types.name == ^name
  end

  def _search(query, :has_purpose, purpose) do
    from badge_types in query,
      where: ^purpose in badge_types.purposes
  end

  def _search(query, :id_list, id_list) do
    from badge_types in query,
      where: badge_types.id in ^id_list
  end

  def _search(query, :simple_search, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from badge_types in query,
      where: (
            ilike(badge_types.name, ^ref_like)
        )
  end

  @spec order_by(Ecto.Query.t, String.t | nil) :: Ecto.Query.t
  def order_by(query, nil), do: query
  def order_by(query, "Name (A-Z)") do
    from badge_types in query,
      order_by: [asc: badge_types.name]
  end

  def order_by(query, "Name (Z-A)") do
    from badge_types in query,
      order_by: [desc: badge_types.name]
  end

  def order_by(query, "Newest first") do
    from badge_types in query,
      order_by: [desc: badge_types.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from badge_types in query,
      order_by: [asc: badge_types.inserted_at]
  end

  @spec preload(Ecto.Query.t, List.t | nil) :: Ecto.Query.t
  def preload(query, nil), do: query
  def preload(query, _preloads) do
    # query = if :things in preloads, do: _preload_things(query), else: query
    query
  end

  # def _preload_things(query) do
  #   from badge_types in query,
  #     left_join: things in assoc(badge_types, :things),
  #     preload: [things: things]
  # end
end
