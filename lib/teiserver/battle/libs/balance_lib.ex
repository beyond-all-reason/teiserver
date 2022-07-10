defmodule Teiserver.Battle.BalanceLib do
  @moduledoc """
  A set of functions related to balance and ratings
  """
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Account
  alias Teiserver.Game.MatchRatingLib

  @type rating() :: number()
  @type user_rating() :: {T.userid(), rating()}

  @spec balance_players([T.userid()], non_neg_integer(), String.t(), :round_robin | :loser_picks) :: map()
  def balance_players(user_ids, team_count, rating_type, mode \\ :loser_picks) do
    players = user_ids
      |> Enum.map(fn userid ->
        {userid, get_skill(userid, rating_type)}
      end)
      |> Enum.sort_by(fn {_, s} -> s end, &>=/2)

    teams = Range.new(1, team_count)
      |> Map.new(fn i ->
        {i, []}
      end)

    team_players = case mode do
      :round_robin ->
        round_robin(players, teams)
      :loser_picks ->
        loser_picks(players, teams)
    end

    stats = team_players
      |> Map.new(fn {team_id, players} ->
        total_rating = players
          |> Enum.reduce(0, fn ({_, rating}, acc) -> acc + rating end)

        {team_id, %{
          total_rating: total_rating
        }}
      end)

    results = %{
      team_players: team_players,
      stats: stats,
      deviation: get_deviation(stats)
    }

    results
  end

  @spec get_skill(T.userid(), String.t()) :: rating()
  def get_skill(userid, rating_type) do
    rating_type_id = MatchRatingLib.rating_type_name_lookup()[rating_type]
    Account.get_rating(userid, rating_type_id) |> convert_rating()
  end

  def convert_rating(nil) do
    MatchRatingLib.default_rating() |> convert_rating()
  end
  def convert_rating(%{mu: mu, sigma: sigma}) do
    Decimal.to_float(mu) - Decimal.to_float(sigma)
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
    max_teamsize = Enum.count(players)/Enum.count(teams) |> :math.ceil() |> round()
    do_loser_picks(players, teams, max_teamsize)
  end

  @spec do_loser_picks([user_rating()], map(), non_neg_integer()) :: map()
  defp do_loser_picks([], teams, _), do: teams
  defp do_loser_picks(players, teams, max_teamsize) do
    team_skills = teams
      |> Enum.reject(fn {_team_number, players} ->
        Enum.count(players) >= max_teamsize
      end)
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

    do_loser_picks(remaining_players, new_team_map, max_teamsize)
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

  @spec get_deviation(map()) :: number()
  defp get_deviation(result_stats) do
    scores = result_stats
      |> Enum.map(fn {_team, stats} ->
        stats.total_rating
      end)
      |> Enum.sort

    [max_score | remaining] = scores
    [min_score | _] = remaining

    # Max score must always be at least one for this to not bork
    max_score = max(max_score, 1)

    ((1 - (min_score/max_score)) * 100)
      |> round
      |> abs
  end

  defp get_skills_from_rating_list(rating_list) do
    rating_list |> Enum.map(fn {_, s} -> s end)
  end
end
