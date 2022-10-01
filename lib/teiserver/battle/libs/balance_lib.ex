defmodule Teiserver.Battle.BalanceLib do
  @moduledoc """
  A set of functions related to balance. Ratings are calculated via Teiserver.Game.MatchRatingLib
  """
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Account
  alias Teiserver.Game.MatchRatingLib
  import Central.Helpers.NumberHelper, only: [int_parse: 1, round: 2]

  @type rating_value() :: float()
  @type player_group() :: %{T.userid() => rating_value()}
  @type expanded_group() :: %{
    members: [T.userid()],
    ratings: [rating_value()],
    group_rating: rating_value(),
    count: non_neg_integer()
  }
  @type expanded_group_or_pair() :: expanded_group() | {expanded_group(), expanded_group()}

  @doc """
  groups is a map of %{userid => rating_value}

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
    start_time = System.system_time(:millisecond)

    # We perform all our group calculations here and assign each group
    # an ID that's used purely for this run of balance
    expanded_groups = groups
      |> Enum.map(fn members ->
        userids = Map.keys(members)
        ratings = Map.values(members)
        %{
          members: userids,
          ratings: ratings,
          group_rating: Enum.sum(ratings),
          count: Enum.count(ratings),
        }
      end)


    # Now we have a list of groups, we need to work out which groups we're going to keep
    # we want to create partner groups but we're only going to do this in a 2 team game
    # because in a team ffa it'll be very problematic
    solo_players = expanded_groups
      |> Enum.filter(fn %{count: count} -> count == 1 end)

    groups = expanded_groups
      |> Enum.filter(fn %{count: count} -> count > 1 end)

    {group_pairs, solo_players, group_logs} = matchup_groups(groups, solo_players, opts)

    # We now need to sort the solo players by rating
    solo_players = solo_players
      |> Enum.sort_by(fn %{group_rating: rating} -> rating end, &>=/2)

    teams = Range.new(1, team_count)
      |> Map.new(fn i ->
        {i, []}
      end)

    {reversed_team_groups, logs} = case opts[:algorithm] || :loser_picks do
      :loser_picks ->
        loser_picks(group_pairs ++ solo_players, teams)
    end

    team_groups = reversed_team_groups
      |> Map.new(fn {team_id, groups} ->
        {team_id, Enum.reverse(groups)}
      end)

    team_players = team_groups
      |> Map.new(fn {team, groups} ->
        players = groups
          |> Enum.map(fn %{members: members} -> members end)
          |> List.flatten

        {team, players}
      end)

    time_taken = System.system_time(:millisecond) - start_time

    %{
      team_groups: team_groups,
      team_players: team_players,
      logs: group_logs ++ logs,
      time_taken: time_taken
    }
      |> calculate_balance_stats
  end

  # We return a list of groups, a list of solo players and logs generated in the process
  # the purpose of this function is to go through the groups, work out which ones we can keep as
  # groups and with the ones we can't, break them up and add them back into the pool of solo
  # players for other groups
  @spec matchup_groups([expanded_group()], [expanded_group()], list()) :: {[expanded_group()], [expanded_group()], [String.t()]}
  defp matchup_groups([], solo_players, _opts), do: {[], solo_players, []}
  defp matchup_groups(groups, solo_players, opts) do
    # First we want to re-sort these groups, we want to have the ones with the highest standard
    # deviation looked at first, they are the least likely to be able to be matched but most likely to
    # help match others
    groups
      |> Enum.sort_by(fn group ->
        Statistics.stdev(group.ratings)
      end, &<=/2)

    do_matchup_groups(groups, solo_players, [], [], opts)
  end

  @spec do_matchup_groups([expanded_group()], [expanded_group()], [String.t], [expanded_group()], list()) :: {[expanded_group()], [expanded_group()], [String.t]}
  defp do_matchup_groups([], solo_players, [], group_pairs, _opts) do
    {group_pairs, solo_players, []}
  end
  defp do_matchup_groups([], solo_players, logs, group_pairs, _opts) do
    {group_pairs, solo_players, logs ++ ["End of pairing"]}
  end
  defp do_matchup_groups([group | remaining_groups], solo_players, logs, group_pairs, opts) do
    group_mean = Enum.sum(group.ratings)/Enum.count(group.ratings)
    group_stddev = Statistics.stdev(group.ratings)

    case find_comparable_group(group, solo_players, opts) do
      :no_possible_combinations ->
        extra_solos = Enum.zip(group.members, group.ratings)
          |> Enum.map(fn {userid, rating} -> %{
              count: 1,
              group_rating: rating,
              members: [userid],
              ratings: [rating]
            }
          end)

        names = group.members
          |> Enum.map(fn userid -> Account.get_username_by_id(userid) || userid end)
          |> Enum.join(", ")

        pairing_logs = [
          "Unable to find a combination match for group of #{names} (stats: #{Enum.sum(group.ratings) |> round(2)}, #{group_mean |> round(2)}, #{group_stddev |> round(2)}), treating them as solo players"
        ]

        do_matchup_groups(remaining_groups, extra_solos ++ solo_players, logs ++ pairing_logs, group_pairs, opts)

      :no_possible_players ->
        extra_solos = Enum.zip(group.members, group.ratings)
          |> Enum.map(fn {userid, rating} -> %{
              count: 1,
              group_rating: rating,
              members: [userid],
              ratings: [rating]
            }
          end)

        names = group.members
          |> Enum.map(fn userid -> Account.get_username_by_id(userid) || userid end)
          |> Enum.join(", ")

        pairing_logs = [
          "Unable to find a player match for group of #{names} (stats: #{Enum.sum(group.ratings) |> round(2)}, #{group_mean |> round(2)}, #{group_stddev |> round(2)}), treating them as solo players"
        ]

        do_matchup_groups(remaining_groups, extra_solos ++ solo_players, logs ++ pairing_logs, group_pairs, opts)

      opposite_group ->
        remaining_solos = solo_players
          |> Enum.reject(fn %{members: [userid]} -> Enum.member?(opposite_group.members, userid) end)

        group_names = group.members
          |> Enum.map(fn userid -> Account.get_username_by_id(userid) || userid end)
          |> Enum.join(", ")

        solo_names = opposite_group.members
          |> Enum.map(fn userid -> Account.get_username_by_id(userid) || userid end)
          |> Enum.join(", ")

        opposite_group_mean = Enum.sum(opposite_group.ratings)/Enum.count(opposite_group.ratings)
        opposite_group_stddev = Statistics.stdev(opposite_group.ratings)

        diff_rating = (Enum.sum(group.ratings) - Enum.sum(opposite_group.ratings)) |> round(2)
        diff_mean = (group_mean - opposite_group_mean) |> round(2)
        diff_stddev = (group_stddev - opposite_group_stddev) |> round(2)

        # First group is the higher rated group, needed for loser_picks algo
        new_pair = if diff_rating > 0 do
          {group, opposite_group}
        else
          {opposite_group, group}
        end

        pair_logs = [
          "Group pairing",
          "> premade: #{group_names}",
          "> adhoc: #{solo_names}",
          "> premade stats #{Enum.sum(group.ratings) |> round(2)}, #{group_mean |> round(2)}, #{group_stddev |> round(2)}",
          "> adhoc stats #{Enum.sum(opposite_group.ratings) |> round(2)}, #{opposite_group_mean |> round(2)}, #{opposite_group_stddev |> round(2)}",
          "> diff_stats #{diff_rating}, #{diff_mean}, #{diff_stddev}"
        ]

        do_matchup_groups(remaining_groups, remaining_solos, logs ++ pair_logs, [new_pair | group_pairs], opts)
    end
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
              |> Map.get(:members)
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
  @spec loser_picks([expanded_group_or_pair()], map()) :: {map(), list()}
  def loser_picks(groups, teams) do
    # teams = do_loser_picks_pairs(premade_pairs, teams)

    # IO.puts ""
    # IO.inspect teams
    # IO.inspect premade_pairs, label: "premade_pairs"
    # IO.puts ""

    total_members = groups
      |> Enum.map(fn
        {%{count: count1}, %{count: count2}} -> count1 + count2
        %{count: count} -> count
      end)
      |> Enum.sum

    max_teamsize = total_members/Enum.count(teams) |> :math.ceil() |> round()
    do_loser_picks(groups, teams, max_teamsize, [])
  end

  @spec do_loser_picks([expanded_group()], map(), non_neg_integer(), list()) :: {map(), list()}
  defp do_loser_picks([], teams, _, logs), do: {teams, logs}
  defp do_loser_picks([picked | remaining_groups], teams, max_teamsize, logs) do
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

    case picked do
      # It's a pair of parties matched up against each other
      {team1_group, team2_group} ->
        [{team1_points, team1}, {team2_points, team2}] = team_skills

        new_team1 = [team1_group | teams[team1]]
        new_team2 = [team2_group | teams[team2]]

        new_team_map = Map.merge(teams, %{
          team1 => new_team1,
          team2 => new_team2,
        })

        team1_names = team1_group.members
          |> Enum.map(fn userid -> Account.get_username_by_id(userid) || userid end)
          |> Enum.join(", ")

        team2_names = team2_group.members
          |> Enum.map(fn userid -> Account.get_username_by_id(userid) || userid end)
          |> Enum.join(", ")

        new_team1_total = (team1_points) + team1_group.group_rating
        new_team2_total = (team2_points) + team2_group.group_rating

        new_logs = logs ++ [
          "Pair picked #{team1_names} for team 1, adding #{round(team1_group.group_rating, 2)} points for new total of #{round(new_team1_total, 2)}",
          "Pair picked #{team2_names} for team 1, adding #{round(team2_group.group_rating, 2)} points for new total of #{round(new_team2_total, 2)}"
        ]

        do_loser_picks(remaining_groups, new_team_map, max_teamsize, new_logs)

      # It's a single player
      _ ->
        current_team = hd(team_skills) |> elem(1)
        new_team = [picked | teams[current_team]]
        new_team_map = Map.put(teams, current_team, new_team)

        names = picked.members
          |> Enum.map(fn userid -> Account.get_username_by_id(userid) || userid end)
          |> Enum.join(", ")

        new_total = (hd(team_skills) |> elem(0)) + picked.group_rating

        new_logs = logs ++ [
          "Picked #{names} for team #{current_team}, adding #{round(picked.group_rating, 2)} points for new total of #{round(new_total, 2)}"
        ]

        do_loser_picks(remaining_groups, new_team_map, max_teamsize, new_logs)
    end
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

  Returns the deviation in percentage points between the two teams
  """
  @spec get_deviation(map()) :: non_neg_integer()
  def get_deviation(team_ratings) do
    scores = team_ratings
      |> Enum.sort_by(fn {_team, rating} -> rating end, &>=/2)

    case scores do
      [] ->
        0
      [_] ->
        0
      _ ->
        raw_scores = scores
          |> Enum.map(fn {_, s} -> s end)

        [max_score | remaining] = raw_scores
        [min_score | _] = remaining

        # Max score skill needs always be at least one for this to not bork
        max_score = max(max_score, 1)

        ((1 - (min_score/max_score)) * 100)
          |> round
          |> abs
    end
  end

  # Given a list of groups, return the combined number of members
  @spec sum_group_membership_size([expanded_group()]) :: non_neg_integer()
  defp sum_group_membership_size([]), do: 0
  defp sum_group_membership_size(groups) do
    groups
      |> Enum.map(fn %{count: count} -> count end)
      |> Enum.sum
  end

  # Given a list of groups, return the combined rating (summed)
  @spec sum_group_rating([expanded_group()]) :: non_neg_integer()
  defp sum_group_rating([]), do: 0
  defp sum_group_rating(groups) do
    groups
      |> Enum.map(fn %{group_rating: group_rating} -> group_rating end)
      |> Enum.sum
  end

  defp get_rating_values_from_rating_list(rating_list) do
    rating_list |> Enum.map(fn {_, s} -> s end)
  end

  @spec calculate_leaderboard_rating(number(), number()) :: number()
  def calculate_leaderboard_rating(skill, uncertainty) do
    skill - (3 * uncertainty)
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
    mean =  sum / count
    stdev = Statistics.stdev(ratings)

    _method1 = ratings
      |> Enum.map(fn r -> max(r, mean) end)
      |> Enum.sum

    _method2 = sum + (stdev * count)
    _method3 = sum + Enum.max(ratings)
    _method4 = sum + mean
    _highest_rank = Enum.max(ratings) * count

    sum
  end

  # Upper boundary is how far above the group value the members can be, lower is how far below it
  @rating_upper_boundary 5
  @rating_upper_boundary 3

  # Stage one, filter out players notably better/worse than the party
  @spec find_comparable_group(expanded_group(), [expanded_group()], list()) :: :no_possible_players | :no_possible_combinations | expanded_group()
  defp find_comparable_group(group, solo_players, opts) do
    rating_lower_bound = Enum.min(group.ratings) - (opts[:rating_lower_boundary] || @rating_upper_boundary)
    rating_upper_bound = Enum.max(group.ratings) + (opts[:rating_upper_boundary] || @rating_upper_boundary)

    possible_players = solo_players
      |> Enum.reject(fn solo ->
        solo.group_rating > rating_upper_bound or solo.group_rating < rating_lower_bound
      end)

    if Enum.count(possible_players) < group.count do
      :no_possible_players
    else
      filter_down_possibles(group, possible_players, opts)
    end
  end

  @mean_diff_max 10
  @stddev_diff_max 4

  # Now we've trimmed our playerlist a bit lets check out the different combinations
  @spec filter_down_possibles(expanded_group(), [expanded_group()], list()) :: :no_possible_combinations | expanded_group()
  defp filter_down_possibles(group, possible_players, opts) do
    group_mean = Enum.sum(group.ratings)/Enum.count(group.ratings)
    group_stddev = Statistics.stdev(group.ratings)

    all_combinations = make_combinations(group.count, possible_players)

      # This first part we are getting the relevant stat info to filter on
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
      |> Enum.sort_by(fn
        {_members, mean_diff, stddev_diff} -> {mean_diff * stddev_diff, mean_diff, stddev_diff}
      end, &<=/2)

    case all_combinations do
      [] ->
        :no_possible_combinations
      _ ->
        {selected_group, _, _} = hd(all_combinations)

        # Now turn a list of groups into one group
        selected_group
          |> Enum.reduce(%{members: [], ratings: [], count: 0, group_rating: 0}, fn (solo, acc) ->
            %{
              members: acc.members ++ solo.members,
              ratings: acc.ratings ++ solo.ratings,
              count: acc.count + 1,
              group_rating: acc.group_rating + solo.group_rating,
            }
          end)
    end
  end

  @spec make_combinations(integer(), list) :: [list]
  defp make_combinations(0, _), do: [[]]
  defp make_combinations(_, []), do: []
  defp make_combinations(n, [x|xs]) do
    (for y <- make_combinations(n - 1, xs), do: [x|y]) ++ make_combinations(n, xs)
  end
end
