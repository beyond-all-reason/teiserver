defmodule Teiserver.Battle.MatchLib do
  use CentralWeb, :library
  alias Teiserver.Client
  alias Teiserver.Battle.{Match, Lobby}

  def game_type(lobby, teams) do
    bot_names = Map.keys(lobby.bots)
      |> Enum.join(" ")

    max_team_size = teams
      |> Enum.map(fn {_, team} -> Enum.count(team) end)
      |> Enum.max

    cond do
      String.contains?(bot_names, "ScavengersAI") and String.contains?(bot_names, "Chicken") -> "PvE"
      String.contains?(bot_names, "ScavengersAI") -> "Scavengers"
      String.contains?(bot_names, "Chicken") -> "Chicken"
      Enum.empty?(lobby.bots) == false -> "Bots"
      Enum.count(teams) == 2 and max_team_size == 1 -> "Duel"
      Enum.count(teams) == 2 -> "Team"
      max_team_size == 1 -> "FFA"
      true -> "Team FFA"
    end
  end

  def match_from_lobby(lobby_id) do
    lobby = Lobby.get_battle!(lobby_id)

    clients = Client.get_clients(lobby.players)

    teams = clients
    |> Enum.filter(fn c -> c.player == true end)
    |> Enum.group_by(fn c -> c.ally_team_number end)

    game_type = game_type(lobby, teams)

    match = %{
      uuid: lobby.tags["server/match/uuid"],
      map: lobby.map_name,
      data: nil,
      tags: Map.drop(lobby.tags, ["server/match/uuid"]),

      team_count: Enum.count(teams),
      team_size: Enum.max(Enum.map(teams, fn {_, t} -> Enum.count(t) end)),
      passworded: (lobby.password != nil),
      game_type: game_type,

      founder_id: lobby.founder_id,
      bots: lobby.bots,

      started: Timex.now(),
      finished: nil
    }

    members = clients
    |> Enum.map(fn client ->
      %{
        user_id: client.userid,
        team_id: client.ally_team_number
      }
    end)

    {match, members}
  end

  def stop_match(lobby_id) do
    lobby = Lobby.get_battle!(lobby_id)
    tag = lobby.tags["server/match/uuid"]
    {tag, %{
      finished: Timex.now()
    }}
  end

  # Functions
  @spec icon :: String.t()
  def icon, do: "far fa-clipboard"
  @spec colours :: {String.t(), String.t(), String.t()}
  def colours, do: Central.Helpers.StylingHelper.colours(:default)

  @spec make_favourite(Map.t()) :: Map.t()
  def make_favourite(match) do
    %{
      type_colour: colours() |> elem(0),
      type_icon: icon(),

      item_id: match.id,
      item_type: "teiserver_battle_match",
      item_colour: colours() |> elem(0),
      item_icon: Teiserver.Battle.MatchLib.icon(),
      item_label: "#{match.name}",

      url: "/battle/matches/#{match.id}"
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

  def _search(query, :uuid, uuid) do
    from matches in query,
      where: matches.uuid == ^uuid
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
  def order_by(query, "Name (A-Z)") do
    from matches in query,
      order_by: [asc: matches.name]
  end

  def order_by(query, "Name (Z-A)") do
    from matches in query,
      order_by: [desc: matches.name]
  end

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
