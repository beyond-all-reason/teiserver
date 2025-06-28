defmodule Teiserver.Matchmaking.Algo.IgnoreOs do
  @moduledoc """
  The simplest possible algorithm for matchmaking.
  It only looks at filling the teams with the correct number of players
  without looking at anything else like wait time or OS.
  This is useful for testing.
  """

  @behaviour Teiserver.Matchmaking.Algos

  alias Teiserver.Matchmaking.Member
  alias Teiserver.Helpers.Combi

  @impl true
  def init(team_size, team_count), do: {team_size, team_count}

  @impl true
  def get_matches(members, {team_size, team_count}) do
    case do_get_matches(members, team_size, team_count, []) do
      [] -> :no_match
      matches -> {:match, matches}
    end
  end

  def do_get_matches(members, team_size, team_count, acc) do
    res =
      match_stream(members, team_size, team_count)
      |> Enum.take(1)
      |> List.first()

    case res do
      nil ->
        acc

      match ->
        ids = for team <- match, member <- team, into: MapSet.new(), do: member.id

        remaining_members =
          Enum.filter(members, fn m ->
            not MapSet.member?(ids, m.id)
          end)

        do_get_matches(remaining_members, team_size, team_count, [match | acc])
    end
  end

  # Returns an enumerable of matches for the given members, team size and team count
  # a match is a list of `team_count` teams. Each teams is a list of member such
  # that the number of player in the team is `team_size`
  @spec match_stream(
          members :: [Member.t()],
          team_size :: pos_integer(),
          team_count :: pos_integer()
        ) :: Enumerable.t([[[Member.t()]]])
  def match_stream(members, team_size, team_count) when team_count <= 1 do
    Combi.combinations(members, team_size)
    |> Stream.map(fn t -> [t] end)
  end

  def match_stream(members, team_size, team_count) do
    teams = Combi.combinations(members, team_size)

    Stream.flat_map(teams, fn team ->
      ids = for member <- team, into: MapSet.new(), do: member.id

      available_members =
        Enum.filter(members, fn m ->
          not MapSet.member?(ids, m.id)
        end)

      other_matches = match_stream(available_members, team_size, team_count - 1)

      Stream.map(other_matches, fn teams -> [team | teams] end)
    end)
  end
end
