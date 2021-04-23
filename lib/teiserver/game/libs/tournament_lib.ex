defmodule Teiserver.Game.TournamentLib do
  use CentralWeb, :library
  alias Teiserver.Game.Tournament

  # Functions
  @spec icon :: String.t()
  def icon, do: "far fa-trophy"
  @spec colours :: {String.t(), String.t(), String.t()}
  def colours, do: Central.Helpers.StylingHelper.colours(:success2)

  @spec make_favourite(Tournament.t()) :: Map.t()
  def make_favourite(tournament) do
    %{
      type_colour: colours() |> elem(0),
      type_icon: icon(),
      item_id: tournament.id,
      item_type: "teiserver_game_tournament",
      item_colour: tournament.colour,
      item_icon: tournament.icon,
      item_label: "#{tournament.name}",
      url: "/teiserver/admin/tournaments/#{tournament.id}"
    }
  end

  # Queries
  @spec query_tournaments() :: Ecto.Query.t()
  def query_tournaments do
    from(tournaments in Tournament)
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
    from tournaments in query,
      where: tournaments.id == ^id
  end

  def _search(query, :name, name) do
    from tournaments in query,
      where: tournaments.name == ^name
  end

  def _search(query, :id_list, id_list) do
    from tournaments in query,
      where: tournaments.id in ^id_list
  end

  def _search(query, :simple_search, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from tournaments in query,
      where: ilike(tournaments.name, ^ref_like)
  end

  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, "Name (A-Z)") do
    from tournaments in query,
      order_by: [asc: tournaments.name]
  end

  def order_by(query, "Name (Z-A)") do
    from tournaments in query,
      order_by: [desc: tournaments.name]
  end

  def order_by(query, "Newest first") do
    from tournaments in query,
      order_by: [desc: tournaments.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from tournaments in query,
      order_by: [asc: tournaments.inserted_at]
  end

  @spec preload(Ecto.Query.t(), List.t() | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, _preloads) do
    # query = if :things in preloads, do: _preload_things(query), else: query
    query
  end

  # def _preload_things(query) do
  #   from tournaments in query,
  #     left_join: things in assoc(tournaments, :things),
  #     preload: [things: things]
  # end
end
