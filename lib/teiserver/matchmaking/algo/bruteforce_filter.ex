defmodule Teiserver.Matchmaking.Algo.BruteforceFilter do
  @moduledoc """
  Rather naive algorithm that will bruteforce all possible pairing of given
  member and picks the one where the match quality is deemed "acceptable".

  This is based on the win prediction falling between certain bounds for
  each member of the team.
  """

  alias Teiserver.Matchmaking.Algo.Env
  alias Teiserver.Matchmaking.Algos
  alias Teiserver.Matchmaking.Member
  @behaviour Algos

  @impl Teiserver.Matchmaking.Algos
  def init(team_size, team_count) do
    %{
      team_size: team_size,
      team_count: team_count
    }
  end

  @impl Teiserver.Matchmaking.Algos
  def get_matches(members, st, %Env{} = env) do
    case Algos.match_members(members, st.team_size, st.team_count, fn members ->
           filter_within_bounds(members, env)
         end) do
      [] -> :no_match
      matches -> {:match, matches}
    end
  end

  defp filter_within_bounds(match, %Env{} = env) do
    team_skills =
      Enum.map(match, fn team ->
        Enum.map(team, fn m ->
          %{skill: skill, uncertainty: uncertainty} = m.rating
          {skill, uncertainty}
        end)
      end)

    predictions = Openskill.predict_win(team_skills)

    match
    |> Enum.zip(predictions)
    |> Enum.all?(fn {team, win_pred} ->
      Enum.all?(team, fn member ->
        {lo, hi} = acceptable_win_proba(member, env)
        win_pred >= lo && win_pred <= hi
      end)
    end)
  end

  # returns a tuple {lo, hi} for acceptable win probability for this member
  # we could also stretch it if the member's skill is at one extreme of
  # the distribution
  defp acceptable_win_proba(%Member{} = member, %Env{} = env) do
    wait_seconds = DateTime.diff(env.now, member.joined_at)

    # some numbers of OS diff and win proba to give an idea:
    # 0 => 0.5
    # 5 => 0.79
    # 10 => 0.95
    # 20 => 0.999
    # `thresholds` is a list of {time in seconds, win proba}. It gives the
    # acceptable win proba after having waited that number of seconds
    thresholds =
      [{0, 0.6}, {15, 0.8}, {30, 0.95}, {60, 0.999}]
      |> Enum.reverse()

    {_time, proba} = Enum.find(thresholds, fn {time, _p} -> wait_seconds >= time end)

    {1 - proba, proba}
  end
end
