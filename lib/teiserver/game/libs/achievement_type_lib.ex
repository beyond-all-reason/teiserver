defmodule Teiserver.Game.AchievementTypeLib do
  use TeiserverWeb, :library
  alias Teiserver.Game.AchievementType

  # Functions
  @spec icon :: String.t()
  def icon, do: "fa-solid fa-star"

  @spec colour :: atom
  def colour, do: :info2

  @spec make_favourite(map()) :: map()
  def make_favourite(achievement_type) do
    %{
      type_colour: colour(),
      type_icon: icon(),
      item_id: achievement_type.id,
      item_type: "teiserver_account_achievement_type",
      item_colour: achievement_type.colour,
      item_icon: achievement_type.icon,
      item_label: "#{achievement_type.name}",
      url: "/account/achievement_types/#{achievement_type.id}"
    }
  end

  # Queries
  @spec query_achievement_types() :: Ecto.Query.t()
  def query_achievement_types do
    from(achievement_types in AchievementType)
  end

  @spec search(Ecto.Query.t(), map() | nil) :: Ecto.Query.t()
  def search(query, nil), do: query

  def search(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _search(query_acc, key, value)
    end)
  end

  @spec _search(Ecto.Query.t(), atom(), any()) :: Ecto.Query.t()
  def _search(query, _, ""), do: query
  def _search(query, _, nil), do: query

  def _search(query, :id, id) do
    from achievement_types in query,
      where: achievement_types.id == ^id
  end

  def _search(query, :name, name) do
    from achievement_types in query,
      where: achievement_types.name == ^name
  end

  def _search(query, :grouping, grouping) do
    from achievement_types in query,
      where: achievement_types.grouping == ^grouping
  end

  def _search(query, :id_list, id_list) do
    from achievement_types in query,
      where: achievement_types.id in ^id_list
  end

  def _search(query, :basic_search, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from achievement_types in query,
      where: ilike(achievement_types.name, ^ref_like)
  end

  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, "Name (A-Z)") do
    from achievement_types in query,
      order_by: [asc: achievement_types.name]
  end

  def order_by(query, "Name (Z-A)") do
    from achievement_types in query,
      order_by: [desc: achievement_types.name]
  end

  def order_by(query, "Newest first") do
    from achievement_types in query,
      order_by: [desc: achievement_types.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from achievement_types in query,
      order_by: [asc: achievement_types.inserted_at]
  end

  @spec preload(Ecto.Query.t(), list() | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, _preloads) do
    # query = if :things in preloads, do: _preload_things(query), else: query
    query
  end

  # def _preload_things(query) do
  #   from achievement_types in query,
  #     left_join: things in assoc(achievement_types, :things),
  #     preload: [things: things]
  # end
end
