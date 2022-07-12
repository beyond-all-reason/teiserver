defmodule Teiserver.Battle.BalanceLib do
  @moduledoc """
  A set of functions related to balance. Ratings are calculated via Teiserver.Game.MatchRatingLib
  """
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Account
  alias Teiserver.Game.MatchRatingLib

  @type rating_value() :: float()
  @type ordinal_sigma_pair() :: {float(), float()}
  @type user_rating() :: {T.userid(), rating_value()}

  @spec balance_players([T.userid()], non_neg_integer(), String.t(), :round_robin | :loser_picks) :: map()
  def balance_players(user_ids, team_count, rating_type, mode \\ :loser_picks) do
    players = user_ids
      |> Enum.map(fn userid ->
        {userid, get_user_rating_value(userid, rating_type)}
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

  @spec default_rating :: List.t()
  @spec default_rating(non_neg_integer()) :: List.t()
  def default_rating(rating_type_id \\ nil) do
    {mu, sigma} = Openskill.rating()
    ordinal = Openskill.ordinal({mu, sigma})

    %{
      rating_type_id: rating_type_id,
      mu: Decimal.from_float(mu * 1.0),
      sigma: Decimal.from_float(sigma * 1.0),
      ordinal: Decimal.from_float(ordinal * 1.0)
    }
  end

  @spec get_user_ordinal_sigma_pair(T.userid(), String.t() | non_neg_integer()) :: ordinal_sigma_pair()
  def get_user_ordinal_sigma_pair(userid, rating_type_id) when is_integer(rating_type_id) do
    rating = Account.get_rating(userid, rating_type_id) || default_rating()

    {
      Decimal.to_float(rating.ordinal),
      Decimal.to_float(rating.sigma)
    }
  end

  def get_user_ordinal_sigma_pair(userid, rating_type) do
    rating_type_id = MatchRatingLib.rating_type_name_lookup()[rating_type]
    get_user_ordinal_sigma_pair(userid, rating_type_id)
  end

  @spec get_user_rating_value(T.userid(), String.t() | non_neg_integer()) :: rating_value()
  def get_user_rating_value(userid, rating_type_id) when is_integer(rating_type_id) do
    Account.get_rating(userid, rating_type_id) |> convert_rating()
  end

  def get_user_rating_value(userid, rating_type) do
    rating_type_id = MatchRatingLib.rating_type_name_lookup()[rating_type]
    get_user_rating_value(userid, rating_type_id)
  end

  @spec convert_rating(map() | nil) :: rating_value()
  def convert_rating(nil) do
    default_rating() |> convert_rating()
  end
  def convert_rating(%{mu: mu, sigma: sigma}) do
    Decimal.to_float(mu) - Decimal.to_float(sigma)
  end

  # Each team takes it in turns to pick, they pick the highest ranked player
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

  # Each round the team with the lowest score picks
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
          |> get_rating_values_from_rating_list()
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
    skills = get_rating_values_from_rating_list(player_list)

    {
      Enum.sum(skills),
      ((Enum.sum(skills) / Enum.count(skills)) * 100 |> round)/100,
    }
  end

  @spec get_deviation(map()) :: number()
  def get_deviation(result_stats) do
    scores = result_stats
      |> Enum.map(fn {_team, stats} ->
        stats.total_rating
      end)
      |> Enum.sort

    case scores do
      [] ->
        0
      [_] ->
        0
      _ ->
        [max_score | remaining] = scores
        [min_score | _] = remaining

        # Max score must always be at least one for this to not bork
        max_score = max(max_score, 1)

        ((1 - (min_score/max_score)) * 100)
          |> round
          |> abs
    end
  end

  defp get_rating_values_from_rating_list(rating_list) do
    rating_list |> Enum.map(fn {_, s} -> s end)
  end
end
