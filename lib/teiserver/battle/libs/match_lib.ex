defmodule Teiserver.Battle.MatchLib do
  use CentralWeb, :library
  alias Teiserver.{Battle, Account}
  alias Teiserver.Battle.Match
  alias Teiserver.Data.Types, as: T
  require Logger

  @spec icon :: String.t()
  def icon, do: "fa-regular fa-swords"

  @spec colours :: atom
  def colours, do: :success2

  @spec game_type(T.lobby(), map()) :: <<_::24, _::_*8>>
  def game_type(lobby, teams) do
    bots = Battle.get_bots(lobby.id)
    bot_names = bots
      |> Map.keys
      |> Enum.join(" ")

    # It is possible for it to be purely bots v bots which will make it appear to be empty teams
    # this would cause an error with Enum.max, hence the case statement
    max_team_size = case Enum.map(teams, fn {_, team} -> Enum.count(team) end) do
      [] ->
        0
      counts ->
        Enum.max(counts)
    end

    cond do
      String.contains?(bot_names, "Scavenger") -> "Scavengers"
      String.contains?(bot_names, "Chicken") -> "Raptors"
      String.contains?(bot_names, "Raptor") -> "Raptors"
      Enum.empty?(bots) == false -> "Bots"
      Enum.count(teams) == 2 and max_team_size == 1 -> "Duel"
      Enum.count(teams) == 2 -> "Team"
      max_team_size == 1 -> "FFA"
      true -> "Team FFA"
    end
  end

  @spec match_from_lobby(T.lobby_id()) :: {map(), list()} | nil
  def match_from_lobby(lobby_id) do
    %{
      lobby: lobby,
      match_uuid: match_uuid,
      server_uuid: server_uuid,
      modoptions: modoptions,
      bots: bots,
      member_list: member_list,
      # player_list: player_list,
      queue_id: queue_id
    } = Battle.get_combined_lobby_state(lobby_id)

    teams = member_list
      |> Account.list_clients()
      |> Enum.filter(fn c -> c.player == true end)
      |> Enum.group_by(fn c -> c.team_number end)

    if teams != %{} do
      the_game_type = game_type(lobby, teams)

      match = %{
        uuid: match_uuid,
        server_uuid: server_uuid,
        map: lobby.map_name,
        data: nil,
        tags: modoptions,

        team_count: Enum.count(teams),
        team_size: Enum.max(Enum.map(teams, fn {_, t} -> Enum.count(t) end)),
        passworded: lobby.passworded,
        game_type: the_game_type,

        founder_id: lobby.founder_id,
        bots: bots,

        queue_id: queue_id,

        started: Timex.now(),
        finished: nil
      }

      members = member_list
        |> Account.list_clients()
        |> Enum.filter(fn c -> c.player == true end)
        |> Enum.map(fn client ->
          %{
            user_id: client.userid,
            team_id: client.team_number,
            party_id: client.party_id
          }
        end)

      {match, members}
    else
      Logger.error("EmptyTeamsMatch Lobby: #{lobby_id}\nMembers: #{Kernel.inspect member_list}")

      nil
    end
  end

  @spec stop_match(T.lobby_id()) :: {String.t(), %{finished: DateTime.t()}}
  def stop_match(lobby_id) do
    modoptions = Battle.get_modoptions(lobby_id)
    tag = modoptions["server/match/uuid"]

    Battle.remove_modoptions(lobby_id, ["server/match/queue_id"])

    {tag, %{
      finished: Timex.now()
    }}
  end

  def make_match_name(nil), do: "Unnamed match"
  def make_match_name(match) do
    case match.game_type do
      "Duel" -> "Duel on #{match.map}"
      "Team" -> "#{match.team_size}v#{match.team_size} on #{match.map}"
      "FFA" -> "#{match.team_count} way FFA on #{match.map}"
      t -> "#{t} game on #{match.map}"
    end
  end

  @spec make_favourite(Map.t()) :: Map.t()
  def make_favourite(match) do
    %{
      type_colour: StylingHelper.colours(colours()) |> elem(0),
      type_icon: icon(),

      item_id: match.id,
      item_type: "teiserver_battle_match",
      # TODO: Make this colour/icon based on type of match
      item_colour: StylingHelper.colours(colours()) |> elem(0),
      item_icon: Teiserver.Battle.MatchLib.icon(),
      item_label: make_match_name(match),

      url: "/teiserver/battle/matches/#{match.id}"
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

  def _search(query, :id_before, id) do
    from matches in query,
      where: matches.id < ^id
  end

  def _search(query, :id_after, id) do
    from matches in query,
      where: matches.id > ^id
  end

  def _search(query, :id_in, ids) do
    from matches in query,
      where: matches.id in ^ids
  end

  def _search(query, :uuid, uuid) do
    from matches in query,
      where: matches.uuid == ^uuid
  end

  def _search(query, :founder_id, founder_id) do
    from matches in query,
      where: matches.founder_id == ^founder_id
  end

  def _search(query, :server_uuid, server_uuid) do
    from matches in query,
      where: matches.server_uuid == ^server_uuid
  end

  def _search(query, :server_uuid_not_nil, _) do
    from matches in query,
      where: not is_nil(matches.server_uuid)
  end

  def _search(query, :name, name) do
    from matches in query,
      where: matches.name == ^name
  end

  def _search(query, :user_id, user_id) do
    from matches in query,
      join: members in assoc(matches, :members),
      where: members.user_id == ^user_id,
      preload: [members: members]
  end

  def _search(query, :user_id_in, user_ids) do
    from matches in query,
      join: members in assoc(matches, :members),
      where: members.user_id in ^user_ids,
      preload: [members: members]
  end

  def _search(query, :user_rating, user_id) do
    from matches in query,
      left_join: ratings in assoc(matches, :ratings),
      where: ratings.user_id == ^user_id or is_nil(ratings.user_id),
      preload: [ratings: ratings]
  end

  def _search(query, :id_list, id_list) do
    from matches in query,
      where: matches.id in ^id_list
  end

  def _search(query, :queue_id, "no_queue") do
    from matches in query,
      where: is_nil(matches.queue_id)
  end
  def _search(query, :queue_id, queue_id) do
    from matches in query,
      where: matches.queue_id == ^queue_id
  end

  def _search(query, :game_type, game_type) do
    from matches in query,
      where: matches.game_type == ^game_type
  end

  def _search(query, :game_type_in, game_types) do
    from matches in query,
      where: matches.game_type in ^game_types
  end

  def _search(query, :game_type_not_in, game_types) do
    from matches in query,
      where: matches.game_type not in ^game_types
  end

  def _search(query, :ready_for_post_process, _) do
    from matches in query,
      where: matches.processed == false,
      where: not is_nil(matches.finished),
      where: not is_nil(matches.started)
  end

  def _search(query, :processed, value) do
    from matches in query,
      where: matches.processed == ^value
  end

  def _search(query, :of_interest, true) do
    from matches in query,
      where: matches.processed == true,
      where: not is_nil(matches.finished),
      where: not is_nil(matches.started)
  end

  def _search(query, :has_winning_team, true) do
    from matches in query,
      where: not is_nil(matches.winning_team)
  end

  def _search(query, :basic_search, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from matches in query,
      where: (
            ilike(matches.name, ^ref_like)
        )
  end

  def _search(query, :never_finished, _) do
    from matches in query,
      where: is_nil(matches.finished)
  end

  def _search(query, :team_size_less_than, size) do
    from matches in query,
      where: matches.team_size < ^size
  end

  def _search(query, :team_size_greater_than, size) do
    from matches in query,
      where: matches.team_size > ^size
  end

  def _search(query, :inserted_after, timestamp) do
    from matches in query,
      where: matches.inserted_at >= ^timestamp
  end

  def _search(query, :inserted_before, timestamp) do
    from matches in query,
      where: matches.inserted_at < ^timestamp
  end

  def _search(query, :started_after, timestamp) do
    from matches in query,
      where: matches.started >= ^timestamp
  end

  def _search(query, :started_before, timestamp) do
    from matches in query,
      where: matches.started < ^timestamp
  end

  def _search(query, :finished_after, timestamp) do
    from matches in query,
      where: matches.finished >= ^timestamp
  end

  def _search(query, :finished_before, timestamp) do
    from matches in query,
      where: matches.finished < ^timestamp
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
      order_by: [desc: matches.started]
  end

  def order_by(query, "Oldest first") do
    from matches in query,
      order_by: [asc: matches.started]
  end

  @spec preload(Ecto.Query.t, List.t | nil) :: Ecto.Query.t
  def preload(query, nil), do: query
  def preload(query, preloads) do
    query = if :members in preloads, do: _preload_members(query), else: query
    query = if :members_and_users in preloads, do: _preload_members_and_users(query), else: query

    query = if :ratings in preloads, do: _preload_ratings(query), else: query

    query = if :queue in preloads, do: _preload_queue(query), else: query
    query
  end

  @spec _preload_members(Ecto.Query.t) :: Ecto.Query.t
  def _preload_members(query) do
    from matches in query,
      left_join: members in assoc(matches, :members),
      preload: [members: members]
  end

  @spec _preload_members_and_users(Ecto.Query.t) :: Ecto.Query.t
  def _preload_members_and_users(query) do
    from matches in query,
      left_join: memberships in assoc(matches, :members),
      left_join: users in assoc(memberships, :user),
      # order_by: [asc: memberships.team_id, asc: users.name],
      preload: [members: {memberships, user: users}]
  end

  @spec _preload_ratings(Ecto.Query.t) :: Ecto.Query.t
  def _preload_ratings(query) do
    from matches in query,
      left_join: ratings in assoc(matches, :ratings),
      preload: [ratings: ratings]
  end

  @spec _preload_queue(Ecto.Query.t) :: Ecto.Query.t
  def _preload_queue(query) do
    from matches in query,
      left_join: queues in assoc(matches, :queue),
      preload: [queue: queues]
  end

  @spec calculate_exit_status(integer(), integer()) :: :stayed | :early | :abandoned | :noshow
  def calculate_exit_status(nil, _), do: :stayed
  def calculate_exit_status(_, nil), do: :stayed
  def calculate_exit_status(left_after, game_duration) do
    diff = game_duration - left_after
    left_percentage = left_after / game_duration

    cond do
      # If you last longer than the game or leave only at the very end you count
      # as having stayed
      left_after > game_duration -> :stayed
      left_percentage >= 0.99 -> :stayed
      diff < 60 -> :stayed

      left_percentage >= 0.9 -> :early

      left_after < 60 -> :noshow

      true -> :abandoned
    end
  end
end
