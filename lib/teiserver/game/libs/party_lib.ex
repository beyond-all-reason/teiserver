defmodule Teiserver.Game.PartyLib do
  use CentralWeb, :library
  alias Teiserver.Game.Party

  # Functions
  @spec icon :: String.t()
  def icon, do: "far fa-user-friends"
  @spec colours :: {String.t(), String.t(), String.t()}
  def colours, do: Central.Helpers.StylingHelper.colours(:info)

  @spec make_favourite(Party.t()) :: Map.t()
  def make_favourite(party) do
    %{
      type_colour: colours() |> elem(0),
      type_icon: icon(),
      item_id: party.id,
      item_type: "teiserver_game_party",
      item_colour: party.colour,
      item_icon: party.icon,
      item_label: "#{party.name}",
      url: "/teiserver/admin/parties/#{party.id}"
    }
  end

  # Queries
  @spec query_parties() :: Ecto.Query.t()
  def query_parties do
    from(parties in Party)
  end

  @spec search(Ecto.Query.t(), Map.t() | nil) :: Ecto.Query.t()
  def search(query, nil), do: query

  def search(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _search(query_acc, key, value)
    end)
  end

  @spec _search(Ecto.Query.t(), Atom.t(), any()) :: Ecto.Query.t()
  def _search(query, _, ""), do: query
  def _search(query, _, nil), do: query

  def _search(query, :id, id) do
    from parties in query,
      where: parties.id == ^id
  end

  def _search(query, :name, name) do
    from parties in query,
      where: parties.name == ^name
  end

  def _search(query, :id_list, id_list) do
    from parties in query,
      where: parties.id in ^id_list
  end

  def _search(query, :simple_search, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from parties in query,
      where: ilike(parties.name, ^ref_like)
  end

  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, "Name (A-Z)") do
    from parties in query,
      order_by: [asc: parties.name]
  end

  def order_by(query, "Name (Z-A)") do
    from parties in query,
      order_by: [desc: parties.name]
  end

  def order_by(query, "Newest first") do
    from parties in query,
      order_by: [desc: parties.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from parties in query,
      order_by: [asc: parties.inserted_at]
  end

  @spec preload(Ecto.Query.t(), List.t() | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, _preloads) do
    # query = if :things in preloads, do: _preload_things(query), else: query
    query
  end

  # def _preload_things(query) do
  #   from parties in query,
  #     left_join: things in assoc(parties, :things),
  #     preload: [things: things]
  # end
end
