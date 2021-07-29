defmodule Teiserver.Battle.MatchLib do
  use CentralWeb, :library
  alias Teiserver.Battle.Match

  # Functions
  @spec icon :: String.t()
  def icon, do: "far fa-clipboard-list"

  @spec colours :: {String.t(), String.t(), String.t()}
  def colours, do: Central.Helpers.StylingHelper.colours(:primary)

  @spec make_favourite(Map.t()) :: Map.t()
  def make_favourite(match) do
    %{
      type_colour: colours() |> elem(0),
      type_icon: icon(),

      item_id: match.id,
      item_type: "teiserver_match",
      item_colour: colours() |> elem(0),
      item_icon: Teiserver.Battle.MatchLib.icon(),
      item_label: "#{match.guid}",

      url: "/teiserver/battle/logs/#{match.id}"
    }
  end

  # Queries
  @spec query_matches() :: Ecto.Query.t
  def query_matches do
    from matches in Match
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
    from matches in query,
      where: matches.id == ^id
  end

  def _search(query, :name, name) do
    from matches in query,
      where: matches.name == ^name
  end

  def _search(query, :id_list, id_list) do
    from matches in query,
      where: matches.id in ^id_list
  end

  def _search(query, :simple_search, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from matches in query,
      where: (
            ilike(matches.name, ^ref_like)
        )
  end

  @spec order_by(Ecto.Query.t, String.t | nil) :: Ecto.Query.t
  def order_by(query, nil), do: query
  def order_by(query, "Newest first") do
    from matches in query,
      order_by: [desc: matches.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from matches in query,
      order_by: [asc: matches.inserted_at]
  end

  @spec preload(Ecto.Query.t, List.t | nil) :: Ecto.Query.t
  def preload(query, nil), do: query
  def preload(query, _preloads) do
    # query = if :things in preloads, do: _preload_things(query), else: query
    query
  end

  # def _preload_things(query) do
  #   from matches in query,
  #     left_join: things in assoc(matches, :things),
  #     preload: [things: things]
  # end
end
