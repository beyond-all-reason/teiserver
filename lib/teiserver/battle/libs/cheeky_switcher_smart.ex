defmodule Teiserver.Battle.CheekySwitcherSmartAlgorithm do
  @moduledoc """
  This algorithm will try to balance the teams by switching the best pair of groups
  between the lowest and highest ranked teams. It will keep doing this until the
  rating difference between the teams is acceptable.

  This algorithm is a bit smarter than the CheekySwitcher algorithm, because it will
  memoize the matchups between the teams. This means that it will not try to switch
  the same pair of groups twice.

  Steps:
  1. Sort the groups by party member count
  2. Place the groups to the smallest teams
  3. Switch the optimal combo of groups between the lowest and highest ranked teams
  4. If the rating difference is acceptable, we are done
  5. If the rating difference is not acceptable, break up the largest party from the teams
  6. Go to step 3, until there are no more parties.
  """

  import Teiserver.Battle.BalanceUtil
  alias Teiserver.Account

  @max_switches 3

  @type expanded_group_or_pair :: BalanceUtils.expanded_group_or_pair
  @type team_map :: BalanceUtils.team_map
  @type group_list :: [expanded_group_or_pair()]

  def has_acceptable_diff (percentage_diff) do
    percentage_diff < 5
  end

  @spec acceptable_teams(team_map()) :: {boolean, number(), number()}
  def acceptable_teams(teams) do
    total_ratings = teams
    |> Enum.map(fn {_k, groups} -> sum_group_rating(groups) end)
    |> Enum.sum()

    rating_diff = max_team_rating_difference(teams)
    percentage_diff = 100 * rating_diff / total_ratings

    {has_acceptable_diff(percentage_diff), rating_diff, percentage_diff}
  end

  @spec cheeky_switcher([expanded_group_or_pair()], number, %{}) :: {team_map(), list()}
  def cheeky_switcher(expanded_groups, team_count, opts) do
    groups_with_names = expanded_groups
      |> Enum.map(fn group ->
        Map.put(group, :names, Enum.map(group.members, fn id ->
          Account.get_username_by_id(id)
        end))
      end)
    do_cheeky_switcher(groups_with_names, team_count, opts, [])
  end
  def do_cheeky_switcher(expanded_groups, team_count, opts, log, start_time \\ System.system_time(:microsecond)) do
    {teams, log} = expanded_groups
    |> sort_groups_by_count()
    |> place_groups_to_smallest_teams(make_empty_teams(team_count), log)
    |> switch_best_rating_diffs()

    {is_acceptable, rating_diff, percentage_diff} = acceptable_teams(teams)

    parties_left = count_parties_in_teams(teams)

    log = log ++ ["Current team ratings: #{team_ratings(teams) |> Enum.map(&round/1) |> Enum.join(", ")}"]

    if is_acceptable or parties_left <= 0 do
      {teams, log  ++ ["Acceptable rating difference of #{round(100 * rating_diff) / 100} (#{round(100 * percentage_diff) / 100} %)."]}
    else
      {groups_without_largest_party, log} = teams_to_groups_without_largest_party(teams, log ++ ["Unacceptable rating difference of #{round(rating_diff)} (#{round(percentage_diff)} %) with current parties."])
      do_cheeky_switcher(
        groups_without_largest_party,
        team_count,
        opts,
        log,
        start_time)
    end
  end

  # Switch the best pair of groups between the lowest and highest ranked teams
  @spec switch_best_rating_diffs({team_map(), list()}) :: {team_map(), list()}
  defp switch_best_rating_diffs({teams, log}) do
    team_rating_diff = max_team_rating_difference(teams)

    if team_rating_diff == 0 do
      {teams, log ++ ["Teams already balanced"]}
    else
      # Since switching two groups will lower one team and raise the other,
      # We aim to find a pair that has a rating difference of half the total.
      # This will result in a total difference of 0.
      # So if we find two groups that have a difference of the equalizing diff, we will
      # get balanced teams.
      equalizing_diff = team_rating_diff / 2

      # Find the best pair of groups to switch between the lowest ranked team
      # and highest ranked team
      case find_best_pair_to_switch(teams, equalizing_diff) do
        %{
          highest_team_id: nil,
          highest_team_combo: [],
          lowest_team_id: nil,
          lowest_team_combo: [],
          best_diff: :infinity
        } ->
          # No pair found, so we can't switch any more
          {teams, log ++ ["No good switch options found."]}
        %{
          highest_team_id: highest_team_id,
          highest_team_combo: highest_team_combo,
          lowest_team_combo: lowest_team_combo,
          lowest_team_id: lowest_team_id,
          combo_switch_diff: _combo_switch_diff,
          best_diff: _best_diff
        } ->
          # Found a pair, so switch them

          lowest_team_members = lowest_team_combo
          |> Enum.map(fn {group, _} ->
            group.names
            |> Enum.with_index()
            |> Enum.map(fn {name, i} -> "#{name}[#{Enum.at(group.ratings,i)}]" end)
          end)
          |> List.flatten()
          |> Enum.join(",")

          highest_team_members = highest_team_combo
          |> Enum.map(fn {group, _} ->
            group.names
            |> Enum.with_index()
            |> Enum.map(fn {name, i} -> "#{name}[#{Enum.at(group.ratings,i)}]" end)
          end)
          |> List.flatten()
          |> Enum.join(",")

          # Switch the best pair
          {switch_group_combos_between_teams(
            teams,
            highest_team_id,
            highest_team_combo,
            lowest_team_id,
            lowest_team_combo
          ),
          log ++ ["Switched users #{lowest_team_members} from team #{lowest_team_id} with users #{highest_team_members} from team #{highest_team_id}"]}
      end
    end
  end

  # Find a pair of groups from the lowest ranked team and highest ranked team
  # that have a rating difference close to equalizing_diff
  @spec find_best_pair_to_switch(team_map(), float()) :: map()
  defp find_best_pair_to_switch(teams, equalizing_diff) do
    {{lowest_team_id, _rating_l}, {highest_team_id, _rating_h}} = lowest_highest_rated_teams(teams)
    highest_team_groups = teams[highest_team_id]
    lowest_team_groups = teams[lowest_team_id]

    biggest_group_size = floor(Enum.count(teams) / 2)

    {highest_team_groups_combos, combo_memo} = make_group_combinations(
      highest_team_groups,
      biggest_group_size,
      true)

    # Find the pair of groups that are closest to the equalizing_diff
    Map.merge(reduce_high_combos(
      0,
      highest_team_groups_combos,
      %{
        highest_team_combo: [],
        lowest_team_combo: [],
        best_diff: :infinity
      },
      lowest_team_groups,
      equalizing_diff, %{}, combo_memo), %{
        highest_team_id: highest_team_id,
        lowest_team_id: lowest_team_id
      })
  end

  # Recursively reduce the highest ranked team's groups to find the best pair to switch
  # with the lowest ranked team.
  defp reduce_high_combos(_i, [], best_pair, _highest_team_groups_combos, _equalizing_diff, _memo, _cm) do best_pair end
  defp reduce_high_combos(i, [highest_team_combo | highest_team_groups_combos], best_pair, lowest_team_groups, equalizing_diff, group_count_memo, combo_memo) do
    highest_team_combo_count = Enum.reduce(highest_team_combo, 0,
      fn {group, _i}, acc -> acc + group.count end)
    highest_combo_rating = Enum.reduce(highest_team_combo, 0,
      fn {group, _i}, acc -> acc + group.group_rating end)

    # make matching groups that can be switched with. In this format:
    # [
    #  [{group1, 1}, {group2, 2}, {group3, 3}],
    #  [{group1, 2}, {group4, 4}], # group 4 has 2 members
    #  [{group2, 2}, {group3, 3}, {group5, 5}],
    #  ...etc for all combinations of groups with the same number of members
    # ]
    {group_count_memo, combo_memo, lowest_team_groups_combos} = make_group_combos_memo(
      lowest_team_groups,
      highest_team_combo_count,
      group_count_memo,
      combo_memo)

    new_best_pair = reduce_low_combos(
      # Drop combinations we have already checked the other way around
      Enum.drop(lowest_team_groups_combos, i),
      best_pair,
      highest_team_combo_count,
      highest_combo_rating,
      highest_team_combo,
      equalizing_diff)

    reduce_high_combos(
      i + 1,
      highest_team_groups_combos,
      new_best_pair,
      lowest_team_groups,
      equalizing_diff,
      group_count_memo,
      combo_memo)
  end

  # Make all combinations of groups with the same number of members, and memoize them
  # so we don't have to make them again
  defp make_group_combos_memo(groups, group_count, group_count_memo, combo_memo) do
    case Map.get(group_count_memo, group_count) do
      nil ->
        {group_combos, combo_memo} = make_group_combinations(groups, group_count, false, combo_memo)
        {Map.put(group_count_memo, group_count, group_combos), combo_memo, group_combos}
      group_combos ->
        {group_count_memo, combo_memo, group_combos}
    end
  end

  # Reduce the lowest ranked team's groups to find the best pair to switch
  # with the highest ranked team.
  defp reduce_low_combos([], best_pair, _expected_combo_count, _highest_combo_rating, _highest_team_combo, _equalizing_diff) do     best_pair end
  defp reduce_low_combos(
    [combo | lowest_team_groups_combos],
    best_pair,
    expected_combo_count,
    highest_combo_rating,
    highest_team_combo,
    equalizing_diff) do
    %{best_diff: best_diff} = best_pair

    combo_members = Enum.reduce(combo, 0,
      fn {group, _i}, acc -> acc + group.count end)
    combo_rating = Enum.reduce(combo, 0,
      fn {group, _i}, acc -> acc + group.group_rating end)

    if expected_combo_count != combo_members do
      # The groups are not the same size, so we can't switch them
      reduce_low_combos(
        lowest_team_groups_combos,
        best_pair,
        expected_combo_count,
        highest_combo_rating,
        highest_team_combo,
        equalizing_diff)
    else
      combo_switch_diff = highest_combo_rating - combo_rating
      diff_from_equalizing = abs(combo_switch_diff - equalizing_diff)

      cond do
        diff_from_equalizing < best_diff -> reduce_low_combos(
          lowest_team_groups_combos,
          %{
            highest_team_combo: highest_team_combo,
            lowest_team_combo: combo,
            best_diff: diff_from_equalizing,
            combo_switch_diff: combo_switch_diff
          },
          expected_combo_count,
          highest_combo_rating,
          highest_team_combo,
          equalizing_diff)
        true -> reduce_low_combos(
          lowest_team_groups_combos,
          best_pair,
          expected_combo_count,
          highest_combo_rating,
          highest_team_combo,
          equalizing_diff)
      end
    end
  end

  @spec place_groups_to_smallest_teams(group_list(), team_map(), list()) :: {team_map(), list()}
  defp place_groups_to_smallest_teams([], teams, log) do
    team_member_diff = max_team_member_count_difference(teams)
    case team_member_diff do
      0 -> {teams, log}
      1 -> {teams, log}
      _ ->
        # Break up the biggest party (there has to be a party) that obstructs
        # making equal teams and restart grouping, which now should be easier to get even.
        {teams_without_largest_party, log} = teams_to_groups_without_largest_party(teams, log ++ ["Teams are not even, breaking up largest party"])
        place_groups_to_smallest_teams(
          teams_without_largest_party,
          make_empty_teams(map_size(teams)),
          log
        )
    end
  end

  defp place_groups_to_smallest_teams([next_group | rest_groups], teams, log) do
    team_key = find_smallest_team_key(teams);
    existing_team_rating = sum_group_rating(teams[team_key])
    placement_logs = make_pick_logs(team_key, next_group, existing_team_rating)
    place_groups_to_smallest_teams(
      rest_groups,
      add_group_to_team(teams, next_group, team_key),
      log ++ placement_logs)
  end

  defp make_pick_logs(team_key, next_group, existing_team_rating) do
    %{ :names => names, :group_rating => group_rating } = next_group
    if next_group.count > 1 do
      ["Group picked #{names |> Enum.join(", ")} for team #{team_key}, adding #{group_rating} points for a new total of #{round(existing_team_rating + group_rating)}"]
    else
      ["Picked #{Enum.at(names, 0)} for team #{team_key}, adding #{group_rating} points for a new total of #{round(existing_team_rating + group_rating)}"]
    end
  end

  @spec teams_to_groups_without_largest_party(map(), list()) :: {group_list(), list()}
  defp teams_to_groups_without_largest_party(teams, log) do
    {new_groups, log} = teams
    # Return to the list of groups
    |> unwind_teams_to_groups()
    # Sort by party size
    |> sort_groups_by_count()
    # Break up the first and largest party
    |> break_up_first_party(log)

    # Sort again by size
    {sort_groups_by_count(new_groups), log}
  end

  defp break_up_first_party([], log) do
    {[], log}
  end
  # Break up the first party in the list of groups
  defp break_up_first_party([group | rest_groups], log) do
    {rest_groups ++ Enum.map(Enum.with_index(group.members),
      fn {member_id, i} -> %{
        count: 1,
        names: [Enum.at(group.names, i)],
        group_rating: Enum.at(group.ratings, i),
        ratings: [Enum.at(group.ratings, i)],
        members: [member_id]
      } end), log ++ ["Breaking up party [#{Enum.join(group.names, ", ")}]"]}
  end

  # Add a group to a team
  @spec add_group_to_team(team_map(), expanded_group_or_pair(), atom()) :: team_map()
  defp add_group_to_team(teams, group, team_key) do
    Map.update!(teams, team_key, fn members -> members ++ [group] end)
  end

  # Get the gey of the team with the smallest number of members
  @spec find_smallest_team_key(team_map()) :: atom()
  defp find_smallest_team_key(teams) do
    Enum.min_by(
      teams,
      fn {_k, team_groups} -> case length(team_groups) do
        0 -> 0
        _ -> sum_group_membership_size(team_groups)
      end
    end)
    |> elem(0)
  end
end
