defmodule Teiserver.Battle.BalanceLib do
  @moduledoc """
  A set of functions related to balance, if you are looking to see how balance is implemented this is the place. Ratings are calculated via Teiserver.Game.MatchRatingLib and are used here. Please note ratings and balance are two very different things and complaints about imbalanced games need to be correct in addressing balance vs ratings.
  """
  alias Teiserver.{Account, Config}
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Battle.Balance.BalanceTypes, as: BT
  alias Teiserver.Game.MatchRatingLib
  import Teiserver.Helper.NumberHelper, only: [int_parse: 1, round: 2]
  require Logger
  # These are default values and can be overridden as part of the call to create_balance()

  # Upper boundary is how far above the group value the members can be, lower is how far below it
  # these values are in general used for group pairing where we look at making temporary groups on
  # each team to make the battle fair
  @rating_lower_boundary 3
  @rating_upper_boundary 5

  @mean_diff_max 5
  @stddev_diff_max 3

  # Fuzz multiplier is used by the BalanceServer to prevent two games being completely identical
  # teams. It is defaulted here as the server uses this library to get defaults
  @fuzz_multiplier 0.5

  # When set to true, if there are any teams with 0 points (first pick) it randomises
  # which one will get to pick first
  @shuffle_first_pick true

  @spec defaults() :: map()
  def defaults() do
    %{
      max_deviation: Config.get_site_config_cache("teiserver.Max deviation"),
      rating_lower_boundary: @rating_lower_boundary,
      rating_upper_boundary: @rating_upper_boundary,
      mean_diff_max: @mean_diff_max,
      stddev_diff_max: @stddev_diff_max,
      fuzz_multiplier: @fuzz_multiplier,
      shuffle_first_pick: @shuffle_first_pick
    }
  end

  def get_default_algorithm() do
    Config.get_site_config_cache("teiserver.Default balance algorithm")
  end

  @spec algorithm_modules() :: %{String.t() => module}
  def algorithm_modules() do
    %{
      "loser_picks" => Teiserver.Battle.Balance.LoserPicks,
      "force_party" => Teiserver.Battle.Balance.ForceParty,
      "brute_force" => Teiserver.Battle.Balance.BruteForce,
      "split_noobs" => Teiserver.Battle.Balance.SplitNoobs,
      "auto" => Teiserver.Battle.Balance.AutoBalance,
      "respect_avoids" => Teiserver.Battle.Balance.RespectAvoids
    }
  end

  @doc """
  Teifion only allowed force_party to be used by mods because it led to noob-stomping unbalanced teams
  """
  @spec get_allowed_algorithms(boolean()) :: [String.t()]
  def get_allowed_algorithms(is_moderator) do
    result =
      if(is_moderator) do
        Teiserver.Battle.BalanceLib.algorithm_modules() |> Map.keys()
      else
        mod_only = ["force_party", "brute_force"]
        Teiserver.Battle.BalanceLib.algorithm_modules() |> Map.drop(mod_only) |> Map.keys()
      end

    ["default" | result]
  end

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
    algorithm: String name of the algorithm

    rating_lower_boundary: the amount of rating points to search below a party
    rating_upper_boundary: the amount of rating points to search above a party

    mean_diff_max: the maximum difference in mean between the party and paired parties
    stddev_diff_max: the maximum difference in stddev between the party and paired parties
  """
  @spec create_balance([BT.player_group()], non_neg_integer) :: map
  def create_balance(groups, team_count) do
    # This method sets default opts (and makes some warnings go away)
    create_balance(groups, team_count, [])
  end

  @spec create_balance([BT.player_group()], non_neg_integer, list) :: map
  def create_balance([], _team_count, _opts) do
    %{
      logs: [],
      time_taken: 0,
      captains: %{},
      deviation: 0,
      ratings: %{},
      team_groups: %{},
      team_players: %{},
      team_sizes: %{},
      means: %{},
      stdevs: %{},
      has_parties?: false
    }
  end

  def create_balance(groups, team_count, opts) do
    start_time = System.system_time(:microsecond)
    groups = standardise_groups(groups)

    # We perform all our group calculations here and assign each group
    # an ID that's used purely for this run of balance
    expanded_groups =
      groups
      |> Enum.map(fn members ->
        userids = Map.keys(members)
        ratings = Map.values(members) |> Enum.map(fn x -> x.rating end)

        ranks =
          Map.values(members)
          |> Enum.map(fn x ->
            cond do
              Map.has_key?(x, :rank) -> x.rank
              true -> 0
            end
          end)

        uncertainties =
          Map.values(members)
          |> Enum.map(fn x ->
            cond do
              Map.has_key?(x, :uncertainty) -> x.uncertainty
              true -> 0
            end
          end)

        names =
          members
          |> Enum.map(fn {id, details} ->
            cond do
              Map.has_key?(details, :name) -> details.name
              true -> "#{id}"
            end
          end)

        %{
          members: userids,
          ratings: ratings,
          ranks: ranks,
          names: names,
          group_rating: Enum.sum(ratings),
          count: Enum.count(ratings),
          uncertainties: uncertainties
        }
      end)

    algo_name = opts[:algorithm] || get_default_algorithm()

    # Now we pass this to the algorithm and it does the rest!
    balance_result =
      case algorithm_modules()[algo_name] do
        nil ->
          raise "No balance module by the name of '#{algo_name}'"

        m ->
          m.perform(expanded_groups, team_count, opts)
      end

    # Now expand the results and calculate stats
    balance_result
    |> expand_balance_result()
    |> calculate_balance_stats
    |> cleanup_result
    |> Map.put(:time_taken, System.system_time(:microsecond) - start_time)
    |> validate_result(groups, team_count, opts)
  end

  def validate_result(result, groups, team_count, opts) do
    if(Enum.empty?(result.team_sizes)) do
      Logger.error("Invalid balance result.")
      Logger.error(result)
      Logger.error("groups: #{Kernel.inspect(groups)}")
      Logger.error("team_count: #{team_count}")
      Logger.error("opts: #{Kernel.inspect(opts)}")
    end

    result
  end

  @doc """
  Sometimes groups have missing data so we need to refetch it.
  If we go through balancer_server then all the required data should be there
  """
  def standardise_groups(groups) do
    groups
    |> Enum.map(fn group ->
      # Iterate over our map
      Map.new(group, fn {user_id, value} ->
        cond do
          is_number(value) ->
            {user_id, get_user_rating_rank_old(user_id, value)}

          # match_controller will use this condition when balancing using old data from game_rating_logs table
          match?(%{"rating_value" => _}, value) ->
            pre_match_stats = get_prematch_stats(value)

            {user_id,
             get_user_rating_rank_old(
               user_id,
               pre_match_stats.rating_value,
               pre_match_stats.uncertainty
             )}

          true ->
            {user_id, value}
        end
      end)
    end)
  end

  # Rating logs use post match data so we must adjust to get prematch data
  defp get_prematch_stats(rating_log_value) do
    new_rating_value = rating_log_value["rating_value"]
    rating_value_change = rating_log_value["rating_value_change"]
    new_uncertainty = rating_log_value["uncertainty"]
    uncertainty_change = rating_log_value["uncertainty_change"]

    %{
      rating_value: new_rating_value - rating_value_change,
      uncertainty: new_uncertainty - uncertainty_change
    }
  end

  # Removes various keys we don't care about
  defp cleanup_result(result) do
    Map.take(
      result,
      ~w(team_groups team_players ratings captains team_sizes deviation means stdevs logs has_parties?)a
    )
  end

  # Only take keys we need
  defp clean_groups(groups) do
    groups
    |> Enum.map(fn x ->
      Map.take(x, ~w(members count group_rating ratings)a)
    end)
  end

  # Take the balance result and add some extra fields to make using it easier
  defp expand_balance_result(balance_result) do
    team_groups =
      cond do
        Map.has_key?(balance_result, :team_groups) ->
          balance_result.team_groups

        true ->
          balance_result.teams
          |> Map.new(fn {team_id, groups} ->
            {team_id, Enum.reverse(clean_groups(groups))}
          end)
      end

    team_players =
      cond do
        Map.has_key?(balance_result, :team_players) ->
          balance_result.team_players

        true ->
          team_groups
          |> Map.new(fn {team, groups} ->
            players =
              groups
              |> Enum.map(fn %{members: members} -> members end)
              |> List.flatten()

            {team, players}
          end)
      end

    Map.merge(balance_result, %{
      team_groups: team_groups,
      team_players: team_players,
      has_parties?: balanced_teams_has_parties?(team_groups)
    })
  end

  @doc """
  We return a list of groups, a list of solo players and logs generated in the process
  the purpose of this function is to go through the groups, work out which ones we can keep as
  groups and with the ones we can't, break them up and add them back into the pool of solo
  players for other groups
  """
  @spec matchup_groups([BT.expanded_group()], [BT.expanded_group()], list()) ::
          {[BT.expanded_group()], [BT.expanded_group()], [String.t()]}
  def matchup_groups([], solo_players, _opts), do: {[], solo_players, []}

  def matchup_groups(groups, solo_players, opts) do
    # First we want to re-sort these groups, we want to have the ones with the highest standard
    # deviation looked at first, they are the least likely to be able to be matched but most likely to
    # help match others
    groups =
      groups
      |> Enum.sort_by(
        fn group ->
          {group.count, Statistics.stdev(group.ratings)}
        end,
        &<=/2
      )

    do_matchup_groups(groups ++ solo_players, [], [], opts)
  end

  # First argument is a list of groups (size 1 included) that need to be paired
  # the second argument is a list of the logs built up by the function
  # thirdly is a list of already paired up groups (so can't be paired up further)
  # fourth is the opts list
  # the function returns a tuple of
  # 1: paired groups
  # 2: non-paired groups
  # 3: logs
  @spec do_matchup_groups([BT.expanded_group()], [String.t()], [BT.expanded_group()], list()) ::
          {[BT.expanded_group()], [BT.expanded_group()], [String.t()]}
  # No groups, no logs
  defp do_matchup_groups([], [], previous_paired_groups, _opts) do
    {previous_paired_groups, [], []}
  end

  # No remaining groups but have some logs
  defp do_matchup_groups([], logs, previous_paired_groups, _opts) do
    {previous_paired_groups, [], logs ++ ["End of pairing"]}
  end

  # This matches when the next group is a size 1, we no longer need to pair up
  defp do_matchup_groups(
         [%{count: 1} | _] = remaining_players,
         logs,
         previous_paired_groups,
         _opts
       ) do
    {previous_paired_groups, remaining_players, logs ++ ["End of pairing"]}
  end

  # Main function clause
  defp do_matchup_groups([group | remaining_groups], logs, previous_paired_groups, opts) do
    group_mean = Enum.sum(group.ratings) / Enum.count(group.ratings)
    group_stddev = Statistics.stdev(group.ratings)

    {_remaining_solo, found_groups} =
      1..(opts[:team_count] - 1)
      |> Enum.reduce({remaining_groups, []}, fn _, {groups_to_search, results} ->
        result = find_comparable_group(group, groups_to_search, opts)

        new_groups_to_search =
          case result do
            :no_possible_combinations ->
              []

            :no_possible_players ->
              []

            %{members: found_members} ->
              groups_to_search
              |> Enum.reject(fn %{members: members} ->
                members
                |> Enum.any?(fn userid -> Enum.member?(found_members, userid) end)
              end)
          end

        {new_groups_to_search, [result | results]}
      end)

    case hd(found_groups) do
      :no_possible_combinations ->
        extra_solos =
          Enum.zip([group.members, group.ratings, group.names])
          |> Enum.map(fn {userid, rating, name} ->
            %{
              count: 1,
              group_rating: rating,
              members: [userid],
              ratings: [rating],
              names: [name]
            }
          end)

        names =
          group.names
          |> Enum.join(", ")

        pairing_logs = [
          "Unable to find a combination match for group of #{names} (stats: #{Enum.sum(group.ratings) |> round(2)}, #{group_mean |> round(2)}, #{group_stddev |> round(2)}), treating them as solo players"
        ]

        do_matchup_groups(
          remaining_groups ++ extra_solos,
          logs ++ pairing_logs,
          previous_paired_groups,
          opts
        )

      :no_possible_players ->
        extra_solos =
          Enum.zip([group.members, group.ratings, group.names])
          |> Enum.map(fn {userid, rating, name} ->
            %{
              count: 1,
              group_rating: rating,
              members: [userid],
              ratings: [rating],
              names: [name]
            }
          end)

        names =
          group.names
          |> Enum.join(", ")

        pairing_logs = [
          "Unable to find a player match for group of #{names} (stats: #{Enum.sum(group.ratings) |> round(2)}, #{group_mean |> round(2)}, #{group_stddev |> round(2)}), treating them as solo players"
        ]

        do_matchup_groups(
          remaining_groups ++ extra_solos,
          logs ++ pairing_logs,
          previous_paired_groups,
          opts
        )

      _ ->
        # Calculate remaining solo players
        combined_member_ids =
          found_groups
          |> Enum.map(fn g -> g.members end)
          |> List.flatten()

        remaining_groups =
          remaining_groups
          |> Enum.reject(fn %{members: members} ->
            members
            |> Enum.any?(fn userid -> Enum.member?(combined_member_ids, userid) end)
          end)

        # Generate log lines, using fgroup so it doesn't clash with group used
        # earlier
        grouped_logs =
          [group | found_groups]
          |> Enum.map(fn fgroup ->
            fgroup_name =
              fgroup.names
              |> Enum.join(", ")

            fgroup_mean = Enum.sum(fgroup.ratings) / Enum.count(fgroup.ratings)
            fgroup_stddev = Statistics.stdev(fgroup.ratings)

            [
              "> Grouped: #{fgroup_name}",
              "--- Rating sum: #{fgroup.group_rating |> round(2)}",
              "--- Rating Mean: #{fgroup_mean |> round(2)}",
              "--- Rating Stddev: #{fgroup_stddev |> round(2)}"
            ]
          end)
          |> List.flatten()

        logs = ["Group matching" | logs]

        # Now order the groups by rating so we can pick in the right order
        found_groups =
          [group | found_groups]
          |> Enum.sort_by(fn fg -> fg.group_rating end, &>=/2)

        do_matchup_groups(
          remaining_groups,
          logs ++ grouped_logs,
          [found_groups | previous_paired_groups],
          opts
        )
    end
  end

  @doc """
  Given a map from create_balance it will add in some stats
  """

  # @spec calculate_balance_stats(map()) :: map()
  # def calculate_balance_stats(%{team_players: []}) do

  # end

  def calculate_balance_stats(data) do
    ratings =
      data.team_groups
      |> Map.new(fn {k, groups} ->
        {k, sum_group_rating(groups)}
      end)

    # The highest rated member of each team is the "captain" by default
    captains =
      if Map.has_key?(data, :captains) do
        data.captains
      else
        data.team_players
        |> Map.new(fn
          {team_id, []} ->
            {team_id, nil}

          {team_id, _players} ->
            top_player = get_captain(data.team_groups[team_id])

            {team_id, top_player}
        end)
      end

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

  @doc """
  Returns the id of the highest rated member

  team_groups =[
      %{
        count: 3,
        ratings: [19, 16, 16],
        members: [112, 113, 114],
        group_rating: 51
      },
      %{count: 2, ratings: [14, 8], members: [115, 116], group_rating: 22},
      %{count: 1, ratings: [41], members: [101], group_rating: 41},
      %{count: 1, ratings: [26], members: [109], group_rating: 26},
      %{count: 1, ratings: [21], members: [111], group_rating: 21}
  ]
  """
  def get_captain(team_groups) do
    flatten_members =
      for %{members: members, ratings: ratings} <- team_groups,
          # Zipping will create binary tuples from 2 lists
          {id, rating} <- Enum.zip(members, ratings),
          # Create result value
          do: %{member_id: id, rating: rating}

    captain = Enum.max_by(flatten_members, fn x -> x.rating end)

    captain.member_id
  end

  @spec default_rating() :: map()
  @spec default_rating(non_neg_integer() | nil) :: map()
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
          {BT.rating_value(), number()}
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
  @spec get_user_rating_value(T.userid(), String.t() | non_neg_integer()) :: BT.rating_value()
  def get_user_rating_value(userid, rating_type_id) when is_integer(rating_type_id) do
    Account.get_rating(userid, rating_type_id) |> convert_rating()
  end

  def get_user_rating_value(_userid, nil), do: nil

  def get_user_rating_value(userid, rating_type) do
    rating_type_id = MatchRatingLib.rating_type_name_lookup()[rating_type]
    get_user_rating_value(userid, rating_type_id)
  end

  @spec get_user_balance_rating_value(T.userid(), String.t() | non_neg_integer()) ::
          BT.rating_value()
  defp get_user_balance_rating_value(userid, rating_type_id) when is_integer(rating_type_id) do
    get_user_rating_value(userid, rating_type_id)
  end

  defp get_user_balance_rating_value(_userid, nil), do: nil

  defp get_user_balance_rating_value(userid, rating_type) do
    rating_type_id = MatchRatingLib.rating_type_name_lookup()[rating_type]
    get_user_balance_rating_value(userid, rating_type_id)
  end

  # Define header to use parameters with default values
  def get_user_rating_rank(userid, rating_type, fuzz_multiplier \\ 1)
  def get_user_rating_rank(_userid, nil, _fuzz_multiplier), do: nil

  def get_user_rating_rank(userid, rating_type, fuzz_multiplier) do
    # This call will go to db or cache
    # The cache for ratings is :teiserver_user_ratings
    # which has an expiry of 60s
    # See application.ex for cache settings
    rating_type_id = MatchRatingLib.rating_type_name_lookup()[rating_type]
    {rating, uncertainty} = get_user_rating_value_uncertainty_pair(userid, rating_type_id)
    rating = fuzz_rating(rating, fuzz_multiplier)

    # Get stats data
    # Potentially adjust ratings based on os_global_adjust
    stats_data = Account.get_user_stat_data(userid)
    adjustment = int_parse(stats_data["os_global_adjust"])
    rating = rating + adjustment
    rank = Map.get(stats_data, "rank", 0)

    # This call will go to db or cache
    # The cache for users is :users
    # which is permanent (and would be instantiated on login)
    # See application.ex for cache settings

    %{name: name} = Account.get_user_by_id(userid)
    %{rating: rating, rank: rank, name: name, uncertainty: uncertainty}
  end

  @doc """
  This is used by some screens to calculate a theoretical balance based on old ratings
  """
  def get_user_rating_rank_old(userid, rating_value, uncertainty \\ 0) do
    stats_data = Account.get_user_stat_data(userid)
    rank = Map.get(stats_data, "rank", 0)

    %{name: name} = Account.get_user_by_id(userid)
    %{rating: rating_value, rank: rank, name: name, uncertainty: uncertainty}
  end

  defp fuzz_rating(rating, multiplier) do
    # Generate something between -1 and 1
    modifier = 1 - :rand.uniform() * 2
    rating + modifier * multiplier
  end

  @doc """
  Given a Rating object or nil, return a value representing the rating to be used
  """
  @spec convert_rating(map() | nil) :: BT.rating_value()
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

  @doc """
  Given a list of groups, return the combined number of members
  """
  @spec sum_group_membership_size([BT.expanded_group()]) :: non_neg_integer()
  def sum_group_membership_size([]), do: 0

  def sum_group_membership_size(groups) do
    groups
    |> Enum.map(fn %{count: count} -> count end)
    |> Enum.sum()
  end

  @doc """
  Given a list of groups, return the combined rating (summed)
  """
  @spec sum_group_rating([BT.expanded_group()]) :: non_neg_integer()
  def sum_group_rating([]), do: 0

  def sum_group_rating(groups) do
    groups
    |> Enum.map(fn %{group_rating: group_rating} -> group_rating end)
    |> Enum.sum()
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

  # Stage one, filter out players notably better/worse than the party
  @spec find_comparable_group(BT.expanded_group(), [BT.expanded_group()], list()) ::
          :no_possible_players | :no_possible_combinations | BT.expanded_group()
  defp find_comparable_group(group, solo_players, opts) do
    rating_lower_bound =
      Enum.min(group.ratings) - (opts[:rating_lower_boundary] || @rating_lower_boundary)

    rating_upper_bound =
      Enum.max(group.ratings) + (opts[:rating_upper_boundary] || @rating_upper_boundary)

    possible_players =
      solo_players
      |> Enum.filter(fn solo ->
        solo.group_rating > rating_lower_bound or solo.group_rating < rating_upper_bound
      end)

    if Enum.count(possible_players) < group.count do
      :no_possible_players
    else
      filter_down_possibles(group, possible_players, opts)
    end
  end

  # Now we've trimmed our playerlist a bit lets check out the different combinations
  @spec filter_down_possibles(BT.expanded_group(), [BT.expanded_group()], list()) ::
          :no_possible_combinations | BT.expanded_group()
  defp filter_down_possibles(group, possible_players, opts) do
    group_mean = Enum.sum(group.ratings) / Enum.count(group.ratings)
    group_stddev = Statistics.stdev(group.ratings)

    sorted_possible_players =
      possible_players
      |> Enum.sort_by(fn g -> Enum.count(g.members) end, &>=/2)

    all_combinations =
      make_combinations(group.count, sorted_possible_players)

      # Filter out bad data (parties can cause bad group sizes)
      |> Stream.filter(fn members ->
        total_count =
          members
          |> Enum.map(fn g -> g.count end)
          |> Enum.sum()

        cond do
          total_count > group.count -> false
          true -> true
        end
      end)

      # This part we are getting the relevant stat info to filter on
      |> Stream.map(fn members ->
        member_ratings = Enum.map(members, fn %{group_rating: group_rating} -> group_rating end)

        members_mean = Enum.sum(member_ratings) / group.count
        members_stddev = Statistics.stdev(member_ratings)

        mean_diff = abs(group_mean - members_mean)
        stddev_diff = abs(group_stddev - members_stddev)

        {members, mean_diff, stddev_diff}
      end)

      # We now filter on differences in mean and stddev
      |> Stream.filter(fn {_members, mean_diff, stddev_diff} ->
        cond do
          mean_diff > (opts[:mean_diff_max] || @mean_diff_max) -> false
          stddev_diff > (opts[:stddev_diff_max] || @stddev_diff_max) -> false
          true -> true
        end
      end)

      # Finally we sort
      |> Enum.sort_by(
        fn
          {_members, mean_diff, stddev_diff} -> {mean_diff * stddev_diff, mean_diff, stddev_diff}
        end,
        &<=/2
      )

    case all_combinations do
      [] ->
        :no_possible_combinations

      _ ->
        {selected_group, _, _} = hd(all_combinations)

        # Now turn a list of groups into one group
        selected_group
        |> Enum.reduce(%{members: [], ratings: [], count: 0, group_rating: 0, names: []}, fn solo,
                                                                                             acc ->
          %{
            members: acc.members ++ solo.members,
            ratings: acc.ratings ++ solo.ratings,
            count: acc.count + solo.count,
            group_rating: acc.group_rating + solo.group_rating,
            names: acc.names ++ solo.names
          }
        end)
    end
  end

  # First argument is the size of each combination
  # Second is the list of items to make a combination from
  @spec make_combinations(integer(), list) :: [list]
  defp make_combinations(0, _), do: [[]]
  defp make_combinations(_, []), do: []

  defp make_combinations(n, [x | xs]) do
    if n < 0 do
      [[]]
    else
      for(y <- make_combinations(n - x.count, xs), do: [x | y]) ++ make_combinations(n, xs)
    end
  end

  @doc """
  Can be called to detect if a balance result has parties
  If the result has no parties we do not need to check team deviation
  """
  def balanced_teams_has_parties?(team_groups) do
    Enum.reduce_while(team_groups, false, fn {_key, team}, _acc ->
      case team_has_parties?(team) do
        true -> {:halt, true}
        false -> {:cont, false}
      end
    end)
  end

  @spec team_has_parties?([BT.group()]) :: boolean()
  def team_has_parties?(team) do
    Enum.reduce_while(team, false, fn x, _acc ->
      group_count = x[:count]

      if group_count > 1 do
        {:halt, true}
      else
        {:cont, false}
      end
    end)
  end
end
