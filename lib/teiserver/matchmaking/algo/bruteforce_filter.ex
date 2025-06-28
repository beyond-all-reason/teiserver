defmodule Teiserver.Matchmaking.Algo.BruteforceFilter do
  @moduledoc """
  Rather naive algorithm that will bruteforce all possible pairing of given
  member and picks the one where the match quality is deemed "acceptable".

  This is based on the win prediction falling between certain bounds for
  each member of the team.
  """

  alias Teiserver.Matchmaking.{Algos, Member}
  @behaviour Algos

  @impl true
  def init(team_size, team_count) do
    %{
      team_size: team_size,
      team_count: team_count
    }
  end

  @impl true
  def get_matches(members, st) do
    case Algos.match_members(members, st.team_size, st.team_count, &filter_within_bounds/1) do
      [] -> :no_match
      matches -> {:match, matches}
    end
  end

  defp filter_within_bounds(match) do
    team_skills =
      Enum.map(match, fn team ->
        Enum.map(team, fn m ->
          %{skill: skill, uncertainty: uncertainty} = m.rating
          {skill, uncertainty}
        end)
      end)

    predictions = Openskill.predict_win(team_skills)

    Enum.all?(Enum.zip(match, predictions), fn {team, win_pred} ->
      Enum.all?(team, fn member ->
        {lo, hi} = acceptable_win_proba(member)
        win_pred >= lo && win_pred <= hi
      end)
    end)
  end

  # returns a tuple {lo, hi} for acceptable win probability for this member
  # we could also stretch it if the member's skill is at one extreme of
  # the distribution
  defp acceptable_win_proba(%Member{} = _member) do
    # TODO: actually do something based on the member
    {0.3, 0.7}
  end
end
