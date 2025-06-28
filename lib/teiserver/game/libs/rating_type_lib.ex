defmodule Teiserver.Game.RatingTypeLib do
  use TeiserverWeb, :library
  alias Teiserver.Game.RatingType

  # Functions
  @spec icon :: String.t()
  def icon, do: "fa-regular fa-star"

  @spec colour :: atom
  def colour, do: :info2

  @spec make_favourite(map()) :: map()
  def make_favourite(rating_type) do
    %{
      type_colour: colour(),
      type_icon: icon(),
      item_id: rating_type.id,
      item_type: "teiserver_game_rating_type",
      item_colour: rating_type.colour,
      item_icon: rating_type.icon,
      item_label: "#{rating_type.name}",
      url: "/game/rating_types/#{rating_type.id}"
    }
  end

  # Queries
  @spec query_rating_types() :: Ecto.Query.t()
  def query_rating_types do
    from(rating_types in RatingType)
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
    from rating_types in query,
      where: rating_types.id == ^id
  end

  def _search(query, :name, name) do
    from rating_types in query,
      where: rating_types.name == ^name
  end

  def _search(query, :id_list, id_list) do
    from rating_types in query,
      where: rating_types.id in ^id_list
  end

  def _search(query, :basic_search, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from rating_types in query,
      where: ilike(rating_types.name, ^ref_like)
  end

  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, "Name (A-Z)") do
    from rating_types in query,
      order_by: [asc: rating_types.name]
  end

  def order_by(query, "Name (Z-A)") do
    from rating_types in query,
      order_by: [desc: rating_types.name]
  end

  def order_by(query, "Newest first") do
    from rating_types in query,
      order_by: [desc: rating_types.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from rating_types in query,
      order_by: [asc: rating_types.inserted_at]
  end

  def order_by(query, "ID (Lowest first)") do
    from rating_types in query,
      order_by: [asc: rating_types.id]
  end

  def order_by(query, "ID (Highest first)") do
    from rating_types in query,
      order_by: [desc: rating_types.id]
  end

  @spec preload(Ecto.Query.t(), [term()] | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, preloads) do
    case preloads[:ratings] do
      nil -> query
      rating_query -> _preload_user(query, rating_query)
    end
  end

  defp _preload_user(query, rating_query) do
    from rating_types in query,
      preload: [ratings: ^rating_query]
  end
end
