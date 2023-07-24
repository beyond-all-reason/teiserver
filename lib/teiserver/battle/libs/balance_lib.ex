defmodule Teiserver.Battle.BalanceLib do
  @moduledoc """
  A set of functions related to balance, if you are looking to see how balance is implemented this is the place. Ratings are calculated via Teiserver.Game.MatchRatingLib and are used here. Please note ratings and balance are two very different things and complaints about imbalanced games need to be correct in addressing balance vs ratings.
  """
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Account
  alias Teiserver.Game.MatchRatingLib
  alias Teiserver.Battle.LoserPicksAlgorithm
  alias Teiserver.Battle.CheekySwitcherSmartAlgorithm
  import Central.Helpers.NumberHelper, only: [int_parse: 1]
  import Teiserver.Battle.BalanceUtil

  @type player_group :: BalanceUtils.player_group
  @type rating_value :: BalanceUtils.rating_value


  @doc """
  groups is a list of maps of %{userid => rating_value}

  The result format with the following keys:
  captains: map of team_id => user_id of highest ranked player in the team
  deviation: non_neg_integer()
  ratings: map of team_id => combined rating_value for team
  team_players: map of team_id => list of userids of players on that team
  team_sizes: map of team_id => non_neg_integer
  team_groups: map of team_id => list of expanded_groups

  Options are:
    mode

    rating_lower_boundary: the amount of rating points to search below a party
    rating_upper_boundary: the amount of rating points to search above a party

    mean_diff_max: the maximum difference in mean between the party and paired parties
    stddev_diff_max: the maximum difference in stddev between the party and paired parties
  """
  @spec create_balance([player_group()], non_neg_integer()) :: map()
  @spec create_balance([player_group()], non_neg_integer(), List.t()) :: map()
  def create_balance(groups, team_count, opts \\ []) do
    start_time = System.system_time(:microsecond)

    # We perform all our group calculations here and assign each group
    # an ID that's used purely for this run of balance
    expanded_groups =
      groups
      |> Enum.map(fn members ->
        userids = Map.keys(members)
        ratings = Map.values(members)

        %{
          members: userids,
          ratings: ratings,
          group_rating: Enum.sum(ratings),
          count: Enum.count(ratings)
        }
      end)

    original_parties = get_parties(expanded_groups)

    # raise "Call"
    {team_groups, logs} =
      case opts[:algorithm] || :loser_picks do
        :loser_picks ->
          LoserPicksAlgorithm.loser_picks(expanded_groups, team_count, opts)
        :cheeky_switcher_smart ->
          CheekySwitcherSmartAlgorithm.cheeky_switcher(expanded_groups, team_count, opts)
      end

    team_players =
      team_groups
      |> Map.new(fn {team, groups} ->
        players =
          groups
          |> Enum.map(fn %{members: members} -> members end)
          |> List.flatten()

        {team, players}
      end)

    parties_preserved =
      original_parties
      |> Enum.filter(fn party ->
        team_groups
        |> Map.values()
        |> Enum.any?(fn team_groups ->
          Enum.any?(team_groups, fn group ->
            Enum.all?(party.members, fn m -> Enum.member?(group.members, m) end)
          end)
        end)
      end)

    parties = {Enum.count(parties_preserved), Enum.count(original_parties)}

    time_taken = System.system_time(:microsecond) - start_time

    %{
      team_groups: team_groups,
      team_players: team_players,
      logs: logs,
      time_taken: time_taken,
      parties: parties
    }
    |> calculate_balance_stats
  end

  @doc """
  Given a map from create_balance it will add in some stats
  """
  @spec calculate_balance_stats(map()) :: map()
  def calculate_balance_stats(data) do
    ratings =
      data.team_groups
      |> Map.new(fn {k, groups} ->
        {k, sum_group_rating(groups)}
      end)

    # The first group in the list will be the highest ranked
    # we take the captain as the first member of that group
    captains =
      data.team_groups
      |> Map.new(fn {k, groups} ->
        case groups do
          [] ->
            {k, nil}

          _ ->
            captain =
              groups
              |> hd
              |> Map.get(:members)
              |> hd

            {k, captain}
        end
      end)

    team_sizes =
      data.team_players
      |> Map.new(fn {team, members} -> {team, Enum.count(members)} end)

    means =
      ratings
      |> Map.new(fn {team, rating_sum} ->
        {team, rating_sum / max(team_sizes[team], 1)}
      end)

    stdevs =
      data.team_groups
      |> Map.new(fn {team, group} ->
        stdev =
          group
          |> Enum.map(fn m -> m.ratings end)
          |> List.flatten()
          |> Statistics.stdev()

        {team, stdev}
      end)

    Map.merge(data, %{
      stdevs: stdevs,
      means: means,
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
      leaderboard_rating: leaderboard_rating
    }
  end

  @spec get_user_rating_value_uncertainty_pair(T.userid(), String.t() | non_neg_integer()) ::
          {rating_value(), number()}
  def get_user_rating_value_uncertainty_pair(userid, rating_type_id)
      when is_integer(rating_type_id) do
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
  @spec get_user_balance_rating_value(T.userid(), String.t() | non_neg_integer()) ::
          rating_value()
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
    max(skill - uncertainty, 0)
  end

  @doc """
  Expects a map of %{team_id => rating_value}

  Returns the deviation in percentage points between the two teams
  """
  @spec get_deviation(map()) :: non_neg_integer()
  def get_deviation(team_ratings) do
    scores =
      team_ratings
      |> Enum.sort_by(fn {_team, rating} -> rating end, &>=/2)

    case scores do
      [] ->
        0

      [_] ->
        0

      _ ->
        raw_scores =
          scores
          |> Enum.map(fn {_, s} -> s end)

        [max_score | remaining] = raw_scores
        [min_score | _] = remaining

        # Max score skill needs always be at least one for this to not bork
        max_score = max(max_score, 1)

        ((1 - min_score / max_score) * 100)
        |> round
        |> abs
    end
  end

  @spec calculate_leaderboard_rating(number(), number()) :: number()
  def calculate_leaderboard_rating(skill, uncertainty) do
    max(skill - 3 * uncertainty, 0)
  end

  @spec balance_group([T.userid()], String.t() | non_neg_integer()) :: number()
  def balance_group(userids, rating_type) do
    userids
    |> Enum.map(fn userid ->
      get_user_balance_rating_value(userid, rating_type)
    end)
    |> balance_group_by_ratings
  end

  @spec balance_group_by_ratings([number()]) :: number()
  def balance_group_by_ratings(ratings) do
    count = Enum.count(ratings)
    sum = Enum.sum(ratings)
    mean = sum / count
    stdev = Statistics.stdev(ratings)

    _method1 =
      ratings
      |> Enum.map(fn r -> max(r, mean) end)
      |> Enum.sum()

    _method2 = sum + stdev * count
    _method3 = sum + Enum.max(ratings)
    _method4 = sum + mean
    _highest_rank = Enum.max(ratings) * count
    sum
  end
end
