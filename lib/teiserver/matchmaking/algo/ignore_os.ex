defmodule Teiserver.Matchmaking.Algo.IgnoreOs do
  @moduledoc """
  The simplest possible algorithm for matchmaking.
  It only looks at filling the teams with the correct number of players
  without looking at anything else like wait time or OS.
  This is useful for testing.
  """

  alias Teiserver.Matchmaking.Algos
  @behaviour Algos

  @impl true
  def init(team_size, team_count), do: {team_size, team_count}

  @impl true
  def get_matches(members, {team_size, team_count}) do
    case Algos.match_members(members, team_size, team_count, fn _ -> true end) do
      [] -> :no_match
      matches -> {:match, matches}
    end
  end
end
