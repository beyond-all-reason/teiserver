defmodule Teiserver.Battle.BalanceLib do
  @moduledoc """
  A set of functions related to balance and ratings
  """
  alias Teiserver.Data.Types, as: T
  @type rating() :: number()
  @type user_rating() :: {T.userid(), rating()}

  @spec balance_players([T.client()], non_neg_integer(), :round_robin | :loser_picks) :: map()
  def balance_players(client_list, team_count, mode \\ :loser_picks) do
    # players_per_team = Enum.count(client_list) / team_count

    players = client_list
      |> Enum.map(fn c ->
        {c.userid, get_skill(c)}
      end)
      |> Enum.sort_by(fn {_, s} -> s end, &>=/2)

    teams = Range.new(1, team_count)
      |> Map.new(fn i ->
        {i, []}
      end)

    case mode do
      :round_robin ->
        round_robin(players, teams)
      :loser_picks ->
        loser_picks(players, teams)
    end
  end

  @spec get_skill(T.client()) :: rating()
  def get_skill(client) do
    client.rank
  end

  @doc """
  Each team takes it in turns to pick, they pick the highest ranked player
  """
  @spec round_robin([user_rating()], map()) :: map()
  defp round_robin(players, teams) do
    do_round_robin(players, teams, 1)
  end

  @spec do_round_robin([user_rating()], map(), non_neg_integer()) :: map()
  defp do_round_robin([], teams, _), do: teams
  defp do_round_robin(players, teams, current_team) do
    team_count = Enum.count(teams)
    [picked | remaining_players] = players

    new_team = [picked | teams[current_team]]
    new_team_map = Map.put(teams, current_team, new_team)

    next_team = if current_team >= team_count, do: 1, else: current_team + 1
    do_round_robin(remaining_players, new_team_map, next_team)
  end

  @doc """
  Each round the team with the lowest score picks
  """
  @spec loser_picks([user_rating()], map()) :: map()
  defp loser_picks(players, teams) do
    do_loser_picks(players, teams)
  end

  @spec do_loser_picks([user_rating()], map()) :: map()
  defp do_loser_picks([], teams), do: teams
  defp do_loser_picks(players, teams) do
    team_skills = teams
      |> Enum.map(fn {team_number, players} ->
        score = players
          |> get_skills_from_rating_list()
          |> Enum.sum

        {score, team_number}
      end)
      |> Enum.sort

    current_team = hd(team_skills) |> elem(1)
    [picked | remaining_players] = players

    new_team = [picked | teams[current_team]]
    new_team_map = Map.put(teams, current_team, new_team)

    do_loser_picks(remaining_players, new_team_map)
  end

  @doc """
  Used to get the stats for a team after it is created via balance
  """
  @spec team_stats([user_rating()]) :: {number, number}
  def team_stats(player_list) do
    skills = get_skills_from_rating_list(player_list)

    {
      Enum.sum(skills),
      ((Enum.sum(skills) / Enum.count(skills)) * 100 |> round)/100,
    }
  end

  defp get_skills_from_rating_list(rating_list) do
    rating_list |> Enum.map(fn {_, s} -> s end)
  end
end
