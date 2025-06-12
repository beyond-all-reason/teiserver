defmodule Teiserver.Matchmaking.Algos do
  @moduledoc """
  Contains the algorithm for matchmaking.
  Currently only has the `ignore_os` function, but is going to have
  at least another one taking OS (and perhaps other parameters) into
  account
  """

  alias Teiserver.Matchmaking.Member
  alias Teiserver.Helpers.Combi

  @doc """
  The simplest possible algorithm for matchmaking.
  It only looks at filling the teams with the correct number of players
  without looking at anything else like wait time or OS.
  This is useful for testing.

  This returns a list of potential matches.
  A match is a list of teams, a team is a list of member
  """
  @spec ignore_os(team_size :: pos_integer(), team_count :: pos_integer(), members: [Member.t()]) ::
          :no_match | {:match, [[[Member.t()]]]}
  def ignore_os(team_size, team_count, members) do
    case get_matches(team_size, team_count, members, []) do
      [] -> :no_match
      matches -> {:match, matches}
    end
  end

  def get_matches(team_size, team_count, members, acc) do
    res =
      match_stream(team_size, team_count, members)
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

        get_matches(team_size, team_count, remaining_members, [match | acc])
    end
  end

  # Returns an enumerable of matches for the given members, team size and team count
  # a match is a list of `team_count` teams. Each teams is a list of member such
  # that the number of player in the team is `team_size`
  @spec match_stream(
          team_size :: pos_integer(),
          team_count :: pos_integer(),
          members :: [Member.t()]
        ) :: Enumerable.t([[[Member.t()]]])
  def match_stream(team_size, team_count, members) when team_count <= 1 do
    Combi.combinations(members, team_size)
    |> Stream.map(fn t -> [t] end)
  end

  def match_stream(team_size, team_count, members) do
    teams = Combi.combinations(members, team_size)

    Stream.flat_map(teams, fn team ->
      ids = for member <- team, into: MapSet.new(), do: member.id

      available_members =
        Enum.filter(members, fn m ->
          not MapSet.member?(ids, m.id)
        end)

      other_matches = match_stream(team_size, team_count - 1, available_members)

      Stream.map(other_matches, fn teams -> [team | teams] end)
    end)
  end
end
