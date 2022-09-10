defmodule Teiserver.Battle.BalanceLib do
  @moduledoc """
  A set of functions related to balance. Ratings are calculated via Teiserver.Game.MatchRatingLib
  """
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Account
  alias Teiserver.Game.MatchRatingLib
  import Central.Helpers.NumberHelper, only: [int_parse: 1]

  @type rating_value() :: float()
  @type group_tuple() :: {[T.userid()], rating_value(), non_neg_integer()}

  @doc """
  groups is a list of pairs, the first item being a list of members (userids) and the second being the rating applied to the group. Note this is the rating for the group as a whole and no additional maths is performed.


  The result format with the following keys:
  captains: map of team_id => user_id of highest ranked player in the team
  deviation: non_neg_integer
  ratings: map of team_id => combined rating_value for team
  team_players: map of team_id => list of userids of players on that team
  team_sizes: map of team_id => non_neg_integer
  team_groups: map of team_id => list of group_tuples, {[userid], rating_value, size}
  """
  @spec create_balance([{[T.userid()], rating_value()}], non_neg_integer(), :round_robin | :loser_picks) :: map()
  def create_balance(groups, team_count, mode \\ :loser_picks) do
    # We want to calculate some values here just to make things faster
    # we add a member count and sort by rating (highest first)
    expanded_groups = groups
      |> Enum.map(fn {members, rating} ->
        {members, rating, Enum.count(members)}
      end)
      |> Enum.sort_by(fn {_members, rating, _size} -> rating end, &>=/2)

    teams = Range.new(1, team_count)
      |> Map.new(fn i ->
        {i, []}
      end)

    team_groups = case mode do
      :loser_picks ->
        loser_picks(expanded_groups, teams)
    end
      |> Map.new(fn {team_id, groups} ->
        {team_id, Enum.reverse(groups)}
      end)

    team_players = team_groups
      |> Map.new(fn {team, groups} ->
        players = groups
          |> Enum.map(fn {members, _, _} -> members end)
          |> List.flatten

        {team, players}
      end)

    %{
      team_groups: team_groups,
      team_players: team_players
    }
      |> calculate_balance_stats
  end

  @doc """
  Given a map from create_balance it will add in some stats
  """
  @spec calculate_balance_stats(map()) :: map()
  def calculate_balance_stats(data) do
    ratings = data.team_groups
      |> Map.new(fn {k, groups} ->
        {k, sum_group_rating(groups)}
      end)

    # The first group in the list will be the highest ranked
    # we take the captain as the first member of that group
    captains = data.team_groups
      |> Map.new(fn {k, groups} ->
        case groups do
          [] ->
            {k, nil}

          _ ->
            captain = groups
              |> hd
              |> elem(0)
              |> hd

            {k, captain}
        end
      end)

    team_sizes = data.team_players
      |> Map.new(fn {team, members} -> {team, Enum.count(members)} end)

    Map.merge(data, %{
      team_sizes: team_sizes,
      ratings: ratings,
      captains: captains,
      deviation: get_deviation(ratings)
    })
  end

  @spec default_rating :: List.t()
  @spec default_rating(non_neg_integer()) :: List.t()
  def default_rating(rating_type_id \\ nil) do
    {skill, uncertainty} = Openskill.rating()
    rating_value = calculate_rating_value(skill, uncertainty)
    leaderboard_rating = calculate_leaderboard_rating(skill, uncertainty)

    %{
      rating_type_id: rating_type_id,
      skill: skill,
      uncertainty: uncertainty,
      rating_value: rating_value,
      leaderboard_rating: leaderboard_rating,
    }
  end

  @spec get_user_rating_value_uncertainty_pair(T.userid(), String.t() | non_neg_integer()) :: {rating_value(), number()}
  def get_user_rating_value_uncertainty_pair(userid, rating_type_id) when is_integer(rating_type_id) do
    rating = Account.get_rating(userid, rating_type_id) || default_rating()

    {
      rating.rating_value,
      rating.uncertainty
    }
  end

  def get_user_rating_value_uncertainty_pair(userid, rating_type) do
    rating_type_id = MatchRatingLib.rating_type_name_lookup()[rating_type]
    get_user_rating_value_uncertainty_pair(userid, rating_type_id)
  end

  @doc """
  Used to get the rating value of the user for public/reporting purposes
  """
  @spec get_user_rating_value(T.userid(), String.t() | non_neg_integer()) :: rating_value()
  def get_user_rating_value(userid, rating_type_id) when is_integer(rating_type_id) do
    Account.get_rating(userid, rating_type_id) |> convert_rating()
  end

  def get_user_rating_value(_userid, nil), do: nil
  def get_user_rating_value(userid, rating_type) do
    rating_type_id = MatchRatingLib.rating_type_name_lookup()[rating_type]
    get_user_rating_value(userid, rating_type_id)
  end

  @doc """
  Used to get the rating value of the user for internal balance purposes which might be
  different from public/reporting
  """
  @spec get_user_balance_rating_value(T.userid(), String.t() | non_neg_integer()) :: rating_value()
  def get_user_balance_rating_value(userid, rating_type_id) when is_integer(rating_type_id) do
    real_rating = get_user_rating_value(userid, rating_type_id)

    stats = Account.get_user_stat_data(userid)
    adjustment = int_parse(stats["os_global_adjust"])

    real_rating + adjustment
  end

  def get_user_balance_rating_value(_userid, nil), do: nil
  def get_user_balance_rating_value(userid, rating_type) do
    rating_type_id = MatchRatingLib.rating_type_name_lookup()[rating_type]
    get_user_balance_rating_value(userid, rating_type_id)
  end

  @doc """
  Given a Rating object or nil, return a value representing the rating to be used
  """
  @spec convert_rating(map() | nil) :: rating_value()
  def convert_rating(nil) do
    default_rating() |> convert_rating()
  end
  def convert_rating(%{rating_value: rating_value}) do
    rating_value
  end

  @spec calculate_rating_value(float(), float()) :: float()
  def calculate_rating_value(skill, uncertainty) do
    skill - uncertainty
  end


  @doc """
  Each round the team with the lowest score picks, if a team has the maximum number of players
  they are not allowed to continue picking.

  groups is a list of tuples: {members, rating, member_count}
  """
  @spec loser_picks([group_tuple()], map()) :: map()
  def loser_picks(groups, teams) do
    total_members = groups
      |> Enum.map(fn {_, _, c} -> c end)
      |> Enum.sum

    max_teamsize = total_members/Enum.count(teams) |> :math.ceil() |> round()
    do_loser_picks(groups, teams, max_teamsize)
  end

  @spec do_loser_picks([group_tuple()], map(), non_neg_integer()) :: map()
  defp do_loser_picks([], teams, _), do: teams
  defp do_loser_picks(groups, teams, max_teamsize) do
    team_skills = teams
      |> Enum.reject(fn {_team_number, member_groups} ->
        size = sum_group_membership_size(member_groups)
        size >= max_teamsize
      end)
      |> Enum.map(fn {team_number, member_groups} ->
        score = sum_group_rating(member_groups)

        {score, team_number}
      end)
      |> Enum.sort

    current_team = hd(team_skills) |> elem(1)
    [picked | remaining_groups] = groups

    new_team = [picked | teams[current_team]]
    new_team_map = Map.put(teams, current_team, new_team)

    do_loser_picks(remaining_groups, new_team_map, max_teamsize)
  end

  @doc """
  Used to get the stats for a team after it is created via balance
  """
  # @spec team_stats([user_rating()]) :: {number, number}
  def team_stats(player_list) do
    skills = get_rating_values_from_rating_list(player_list)

    {
      Enum.sum(skills),
      ((Enum.sum(skills) / Enum.count(skills)) * 100 |> round)/100,
    }
  end


  @doc """
  Expects a map of %{team_id => rating_value}

  Returns a pair of {best_team, deviation}
  """
  @spec get_deviation(map()) :: {non_neg_integer(), number()}
  def get_deviation(team_ratings) do
    scores = team_ratings
      |> Enum.sort_by(fn {_team, rating} -> rating end, &>=/2)

    case scores do
      [] ->
        {nil, 0}
      [_] ->
        {1, 0}
      _ ->
        top_team = hd(scores)
          |> elem(0)

        raw_scores = scores
          |> Enum.map(fn {_, s} -> s end)

        [max_score | remaining] = raw_scores
        [min_score | _] = remaining

        # Max score skill needs always be at least one for this to not bork
        max_score = max(max_score, 1)

        deviation = ((1 - (min_score/max_score)) * 100)
          |> round
          |> abs

        {top_team, deviation}
    end
  end

  # Given a list of groups, return the combined number of members
  @spec sum_group_membership_size([group_tuple()]) :: non_neg_integer()
  defp sum_group_membership_size([]), do: 0
  defp sum_group_membership_size(groups) do
    groups
      |> Enum.map(fn {_, _, count} -> count end)
      |> Enum.sum
  end

  # Given a list of groups, return the combined rating (summed)
  @spec sum_group_rating([group_tuple()]) :: non_neg_integer()
  defp sum_group_rating([]), do: 0
  defp sum_group_rating(groups) do
    groups
      |> Enum.map(fn {_, rating, _} -> rating end)
      |> Enum.sum
  end

  defp get_rating_values_from_rating_list(rating_list) do
    rating_list |> Enum.map(fn {_, s} -> s end)
  end

  @spec calculate_leaderboard_rating(number(), number()) :: number()
  def calculate_leaderboard_rating(skill, uncertainty) do
    skill - (3 * uncertainty)
  end

  @spec balance_party([T.userid()], String.t() | non_neg_integer()) :: number()
  def balance_party(userids, rating_type) do
    ratings = userids
      |> Enum.map(fn userid ->
        get_user_balance_rating_value(userid, rating_type)
      end)

    count = Enum.count(ratings)
    sum = Enum.sum(ratings)
    mean =  sum / count
    stdev = Statistics.stdev(ratings)

    _method1 = ratings
      |> Enum.map(fn r -> max(r, mean) end)
      |> Enum.sum

    method2 = sum + (stdev * count)
    _method3 = sum + Enum.max(ratings)
    _method4 = sum + mean

    method2
  end
end
