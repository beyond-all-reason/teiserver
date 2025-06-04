defmodule Teiserver.Matchmaking.Algos do
  @moduledoc """
  The simplest possible matchmaking algoright, ignore OS values, and simply
  put players together, respecting parties and team size
  """

  alias Teiserver.Matchmaking.Member

  @doc """
  This returns a list of potential matches.
  A match is a list of teams, a team is a list of member

  It only looks at filling the teams with the correct number of players
  without looking at anything else like wait time or OS.
  This is useful for testing
  """
  @spec ignore_os(team_size :: pos_integer(), team_count :: pos_integer(),
          members: [Member.t()]
        ) :: :no_match | {:match, [[[Member.t()]]]}
  def ignore_os(team_size, team_count, members) do
    case greedy_match(team_size, team_count, members, [], []) do
      [] -> :no_match
      matches -> {:match, matches}
    end
  end

  defp greedy_match(team_size, team_count, members, current_team, matched) do
    # tachyon_mvp: this is a temporary algorithm
    # it only looks at the number of players to fill a team
    case members do
      [] ->
        Enum.chunk_every(matched, team_count, team_count, :discard)

      members ->
        current_size =
          current_team |> Enum.map(fn member -> Enum.count(member.player_ids) end) |> Enum.sum()

        case Enum.split_while(members, fn m ->
               Enum.count(m.player_ids) + current_size > team_size
             end) do
          # current team cannot be completed, discard it
          {_, []} ->
            greedy_match(team_size, team_count, members, [], matched)

          {too_big, [member | rest]} ->
            to_add = Enum.count(member.player_ids)
            rest = too_big ++ rest

            cond do
              current_size + to_add < team_size ->
                greedy_match(team_size, team_count, rest, [member | current_team], matched)

              current_size + to_add == team_size ->
                greedy_match(team_size, team_count, rest, [], [[member | current_team] | matched])
            end
        end
    end
  end
end
