defmodule Teiserver.Battle.Balance.CheekySwitcherSmart do
  @moduledoc """
  Created by fumbleforce as part of PR 139.

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

  # Alias the types
  alias Teiserver.Battle.BalanceLib
  alias Teiserver.Battle.Balance.BalanceTypes, as: BT

  # @type algorithm_state :: %{
  #   teams: map,
  #   logs: list,
  #   solo_players: list,
  #   opts: list
  # }

  @type team_map() :: %{T.team_id() => [BT.expanded_group()]}
  @type group_list :: [BT.expanded_group_or_pair()]

  @spec perform([BT.expanded_group_or_pair()], non_neg_integer(), list()) :: BT.algorithm_result()
  def perform(raw_groups, team_count, opts) do
    groups_with_names = Enum.map(raw_groups, fn x -> Map.drop(x, [:ranks]) end)

    {teams, logs} = do_cheeky_switcher(groups_with_names, team_count, opts, [])

    new_teams =
      teams
      |> Map.new(fn {k, members} ->
        new_members =
          members
          |> Enum.map(fn m -> Map.drop(m, [:names]) end)

        {k, new_members}
      end)

    %{
      teams: new_teams,
      logs: logs
    }
  end

  def has_acceptable_diff(percentage_diff) do
    percentage_diff < 5
  end

  @spec acceptable_teams(team_map()) :: {boolean, number(), number()}
  def acceptable_teams(teams) do
    total_ratings =
      teams
      |> Enum.map(fn {_k, groups} -> BalanceLib.sum_group_rating(groups) end)
      |> Enum.sum()

    rating_diff = max_team_rating_difference(teams)
    percentage_diff = 100 * rating_diff / total_ratings

    {has_acceptable_diff(percentage_diff), rating_diff, percentage_diff}
  end

  def do_cheeky_switcher(
        expanded_groups,
        team_count,
        opts,
        log,
        start_time \\ System.system_time(:microsecond)
      ) do
    {teams, log} =
      expanded_groups
      |> sort_groups_by_count()
      |> place_groups_to_smallest_teams(make_empty_teams(team_count), log)
      |> switch_best_rating_diffs()

    {is_acceptable, rating_diff, percentage_diff} = acceptable_teams(teams)

    parties_left = count_parties_in_teams(teams)

    log = log ++ ["Current team ratings: #{team_ratings(teams) |> Enum.map_join(",", &round/1)}"]

    if is_acceptable or parties_left <= 0 do
      {teams,
       log ++
         [
           "Acceptable rating difference of #{round(100 * rating_diff) / 100} (#{round(100 * percentage_diff) / 100} %)."
         ]}
    else
      {groups_without_largest_party, log} =
        teams_to_groups_without_largest_party(
          teams,
          log ++
            [
              "Unacceptable rating difference of #{round(rating_diff)} (#{round(percentage_diff)} %) with current parties."
            ]
        )

      do_cheeky_switcher(
        groups_without_largest_party,
        team_count,
        opts,
        log,
        start_time
      )
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

          lowest_team_members =
            lowest_team_combo
            |> Enum.map(fn {group, _} ->
              group.names
              |> Enum.with_index()
              |> Enum.map(fn {name, i} -> "#{name}[#{Enum.at(group.ratings, i)}]" end)
            end)
            |> List.flatten()
            |> Enum.join(",")

          highest_team_members =
            highest_team_combo
            |> Enum.map(fn {group, _} ->
              group.names
              |> Enum.with_index()
              |> Enum.map(fn {name, i} -> "#{name}[#{Enum.at(group.ratings, i)}]" end)
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
           log ++
             [
               "Switched users #{lowest_team_members} from team #{lowest_team_id} with users #{highest_team_members} from team #{highest_team_id}"
             ]}

        _ ->
          # Default case
          {teams, log ++ ["No good switch options found."]}
      end
    end
  end

  # Find a pair of groups from the lowest ranked team and highest ranked team
  # that have a rating difference close to equalizing_diff
  @spec find_best_pair_to_switch(team_map(), float()) :: map()
  defp find_best_pair_to_switch(teams, equalizing_diff) do
    {{lowest_team_id, _rating_l}, {highest_team_id, _rating_h}} =
      lowest_highest_rated_teams(teams)

    highest_team_groups = teams[highest_team_id]
    lowest_team_groups = teams[lowest_team_id]

    biggest_group_size = floor(Enum.count(teams) / 2)

    {highest_team_groups_combos, combo_memo} =
      make_group_combinations(
        highest_team_groups,
        biggest_group_size,
        true
      )

    # Find the pair of groups that are closest to the equalizing_diff
    Map.merge(
      reduce_high_combos(
        0,
        highest_team_groups_combos,
        %{
          highest_team_combo: [],
          lowest_team_combo: [],
          best_diff: :infinity
        },
        lowest_team_groups,
        equalizing_diff,
        %{},
        combo_memo
      ),
      %{
        highest_team_id: highest_team_id,
        lowest_team_id: lowest_team_id
      }
    )
  end

  # Recursively reduce the highest ranked team's groups to find the best pair to switch
  # with the lowest ranked team.
  defp reduce_high_combos(
         _i,
         [],
         best_pair,
         _highest_team_groups_combos,
         _equalizing_diff,
         _memo,
         _cm
       ) do
    best_pair
  end

  defp reduce_high_combos(
         i,
         [highest_team_combo | highest_team_groups_combos],
         best_pair,
         lowest_team_groups,
         equalizing_diff,
         group_count_memo,
         combo_memo
       ) do
    highest_team_combo_count =
      Enum.reduce(highest_team_combo, 0, fn {group, _i}, acc -> acc + group.count end)

    highest_combo_rating =
      Enum.reduce(highest_team_combo, 0, fn {group, _i}, acc -> acc + group.group_rating end)

    # make matching groups that can be switched with. In this format:
    # [
    #  [{group1, 1}, {group2, 2}, {group3, 3}],
    #  [{group1, 2}, {group4, 4}], # group 4 has 2 members
    #  [{group2, 2}, {group3, 3}, {group5, 5}],
    #  ...etc for all combinations of groups with the same number of members
    # ]
    {group_count_memo, combo_memo, lowest_team_groups_combos} =
      make_group_combos_memo(
        lowest_team_groups,
        highest_team_combo_count,
        group_count_memo,
        combo_memo
      )

    new_best_pair =
      reduce_low_combos(
        # Drop combinations we have already checked the other way around
        Enum.drop(lowest_team_groups_combos, i),
        best_pair,
        highest_team_combo_count,
        highest_combo_rating,
        highest_team_combo,
        equalizing_diff
      )

    reduce_high_combos(
      i + 1,
      highest_team_groups_combos,
      new_best_pair,
      lowest_team_groups,
      equalizing_diff,
      group_count_memo,
      combo_memo
    )
  end

  # Make all combinations of groups with the same number of members, and memoize them
  # so we don't have to make them again
  defp make_group_combos_memo(groups, group_count, group_count_memo, combo_memo) do
    case Map.get(group_count_memo, group_count) do
      nil ->
        {group_combos, combo_memo} =
          make_group_combinations(groups, group_count, false, combo_memo)

        {Map.put(group_count_memo, group_count, group_combos), combo_memo, group_combos}

      group_combos ->
        {group_count_memo, combo_memo, group_combos}
    end
  end

  # Reduce the lowest ranked team's groups to find the best pair to switch
  # with the highest ranked team.
  defp reduce_low_combos(
         [],
         best_pair,
         _expected_combo_count,
         _highest_combo_rating,
         _highest_team_combo,
         _equalizing_diff
       ) do
    best_pair
  end

  defp reduce_low_combos(
         [combo | lowest_team_groups_combos],
         best_pair,
         expected_combo_count,
         highest_combo_rating,
         highest_team_combo,
         equalizing_diff
       ) do
    %{best_diff: best_diff} = best_pair

    combo_members = Enum.reduce(combo, 0, fn {group, _i}, acc -> acc + group.count end)
    combo_rating = Enum.reduce(combo, 0, fn {group, _i}, acc -> acc + group.group_rating end)

    if expected_combo_count != combo_members do
      # The groups are not the same size, so we can't switch them
      reduce_low_combos(
        lowest_team_groups_combos,
        best_pair,
        expected_combo_count,
        highest_combo_rating,
        highest_team_combo,
        equalizing_diff
      )
    else
      combo_switch_diff = highest_combo_rating - combo_rating
      diff_from_equalizing = abs(combo_switch_diff - equalizing_diff)

      cond do
        diff_from_equalizing < best_diff ->
          reduce_low_combos(
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
            equalizing_diff
          )

        true ->
          reduce_low_combos(
            lowest_team_groups_combos,
            best_pair,
            expected_combo_count,
            highest_combo_rating,
            highest_team_combo,
            equalizing_diff
          )
      end
    end
  end

  @spec place_groups_to_smallest_teams(BT.group_list(), team_map, list()) :: {team_map, list()}
  defp place_groups_to_smallest_teams([], teams, log) do
    team_member_diff = max_team_member_count_difference(teams)

    case team_member_diff do
      0 ->
        {teams, log}

      1 ->
        {teams, log}

      _ ->
        # Break up the biggest party (there has to be a party) that obstructs
        # making equal teams and restart grouping, which now should be easier to get even.
        {teams_without_largest_party, log} =
          teams_to_groups_without_largest_party(
            teams,
            log ++ ["Teams are not even, breaking up largest party"]
          )

        place_groups_to_smallest_teams(
          teams_without_largest_party,
          make_empty_teams(map_size(teams)),
          log
        )
    end
  end

  defp place_groups_to_smallest_teams([next_group | rest_groups], teams, log) do
    team_key = find_smallest_team_key(teams)
    existing_team_rating = sum_group_rating(teams[team_key])
    placement_logs = make_pick_logs(team_key, next_group, existing_team_rating)

    place_groups_to_smallest_teams(
      rest_groups,
      add_group_to_team(teams, next_group, team_key),
      log ++ placement_logs
    )
  end

  defp make_pick_logs(team_key, next_group, existing_team_rating) do
    %{:names => names, :group_rating => group_rating} = next_group

    if next_group.count > 1 do
      [
        "Group picked #{names |> Enum.join(", ")} for team #{team_key}, adding #{group_rating} points for a new total of #{round(existing_team_rating + group_rating)}"
      ]
    else
      [
        "Picked #{Enum.at(names, 0)} for team #{team_key}, adding #{group_rating} points for a new total of #{round(existing_team_rating + group_rating)}"
      ]
    end
  end

  @spec teams_to_groups_without_largest_party(map(), list()) :: {group_list, list()}
  defp teams_to_groups_without_largest_party(teams, log) do
    {new_groups, log} =
      teams
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
    {rest_groups ++
       Enum.map(
         Enum.with_index(group.members),
         fn {member_id, i} ->
           %{
             count: 1,
             names: [Enum.at(group.names, i)],
             group_rating: Enum.at(group.ratings, i),
             ratings: [Enum.at(group.ratings, i)],
             members: [member_id]
           }
         end
       ), log ++ ["Breaking up party [#{Enum.join(group.names, ", ")}]"]}
  end

  # Add a group to a team
  @spec add_group_to_team(team_map(), BT.expanded_group_or_pair(), atom()) :: team_map()
  defp add_group_to_team(teams, group, team_key) do
    Map.update!(teams, team_key, fn members -> members ++ [group] end)
  end

  # Get the gey of the team with the smallest number of members
  @spec find_smallest_team_key(team_map()) :: atom()
  defp find_smallest_team_key(teams) do
    Enum.min_by(
      teams,
      fn {_k, team_groups} ->
        case length(team_groups) do
          0 -> 0
          _ -> sum_group_membership_size(team_groups)
        end
      end
    )
    |> elem(0)
  end

  # Given a list of groups, return the combined number of members
  @spec sum_group_membership_size([BT.expanded_group()]) :: non_neg_integer()
  def sum_group_membership_size([]), do: 0

  def sum_group_membership_size(groups) do
    groups
    |> Enum.map(fn %{count: count} -> count end)
    |> Enum.sum()
  end

  # Given a list of groups, return the combined rating (summed)
  @spec sum_group_rating([BT.expanded_group()]) :: non_neg_integer()
  def sum_group_rating([]), do: 0

  def sum_group_rating(groups) do
    groups
    |> Enum.map(fn %{group_rating: group_rating} -> group_rating end)
    |> Enum.sum()
  end

  @spec min_max_difference([non_neg_integer()]) :: non_neg_integer()
  def min_max_difference(list) do
    Enum.max(list) - Enum.min(list)
  end

  @spec max_team_member_count_difference(team_map()) :: non_neg_integer()
  def max_team_member_count_difference(teams) do
    teams
    |> Enum.map(fn {_k, team_groups} -> sum_group_membership_size(team_groups) end)
    |> min_max_difference()
  end

  @spec max_team_rating_difference(team_map()) :: non_neg_integer()
  def max_team_rating_difference([]) do
    0
  end

  def max_team_rating_difference([_team]) do
    0
  end

  def max_team_rating_difference(teams) do
    teams
    |> Enum.map(fn {_k, team_groups} -> sum_group_rating(team_groups) end)
    |> min_max_difference()
  end

  @spec make_empty_teams(non_neg_integer()) :: team_map()
  def make_empty_teams(team_count) do
    Range.new(1, team_count)
    |> Map.new(fn i ->
      {i, []}
    end)
  end

  @spec sort_groups_by_rating([BT.expanded_group()]) :: [BT.expanded_group()]
  def sort_groups_by_rating(groups) do
    Enum.sort_by(
      groups,
      fn %{group_rating: rating} -> rating end,
      :desc
    )
  end

  @spec sort_groups_by_count([BT.expanded_group()]) :: [BT.expanded_group()]
  def sort_groups_by_count(groups) do
    Enum.sort_by(
      groups,
      fn %{count: count} -> count end,
      :desc
    )
  end

  @spec unwind_teams_to_groups(team_map()) :: [BT.expanded_group()]
  def unwind_teams_to_groups(teams) do
    Enum.flat_map(teams, fn {_k, team_groups} -> team_groups end)
  end

  @spec get_parties([BT.expanded_group()]) :: [BT.expanded_group()]
  def get_parties(groups) do
    groups
    |> Enum.filter(fn group -> group.count > 1 end)
  end

  @spec count_parties([BT.expanded_group()]) :: non_neg_integer()
  def count_parties(groups) do
    get_parties(groups)
    |> length()
  end

  @spec count_parties_in_teams(team_map()) :: number()
  def count_parties_in_teams(teams) do
    teams
    |> Map.values()
    |> Enum.map(fn groups -> count_parties(groups) end)
    |> Enum.sum()
  end

  def team_ratings(teams) do
    teams
    |> Enum.map(fn {_id, groups} -> sum_group_rating(groups) end)
  end

  def team_means(teams) do
    teams
    |> Enum.map(fn {_id, groups} ->
      sum_group_rating(groups) / sum_group_membership_size(groups)
    end)
  end

  def team_stddevs(teams) do
    teams
    |> Enum.map(fn {_id, groups} ->
      Statistics.stdev(Enum.flat_map(groups, fn group -> group.ratings end))
    end)
  end

  @spec has_parties(team_map()) :: boolean()
  def has_parties(teams) do
    teams
    |> Enum.any?(fn {_k, team_groups} ->
      Enum.any?(team_groups, fn %{count: count} -> count > 1 end)
    end)
  end

  @spec replace_team_group_at_index(
          team_map(),
          T.team_id(),
          non_neg_integer(),
          BT.expanded_group()
        ) :: team_map()
  def replace_team_group_at_index(teams, team_id, group_index, group) do
    Map.put(teams, team_id, List.replace_at(teams[team_id], group_index, group))
  end

  @spec switch_group_pair_between_teams(
          team_map(),
          T.team_id(),
          non_neg_integer(),
          T.team_id(),
          non_neg_integer()
        ) :: team_map()
  def switch_group_pair_between_teams(
        teams,
        team_a_id,
        group_a_index,
        team_b_id,
        group_b_index
      ) do
    team_a_groups = teams[team_a_id]
    group_a = Enum.at(team_a_groups, group_a_index)
    team_b_groups = teams[team_b_id]
    group_b = Enum.at(team_b_groups, group_b_index)

    replace_team_group_at_index(teams, team_a_id, group_a_index, group_b)
    |> replace_team_group_at_index(team_b_id, group_b_index, group_a)
  end

  @spec switch_group_pair_between_teams(team_map(), T.team_id(), non_neg_integer(), T.team_id(), [
          {BT.expanded_group(), non_neg_integer()}
        ]) :: team_map()
  def switch_group_with_combo_between_teams(
        teams,
        team_a_id,
        group_a_index,
        team_b_id,
        group_b_combo
      ) do
    team_a_groups = teams[team_a_id]
    team_b_groups = teams[team_b_id]
    group_a = Enum.at(team_a_groups, group_a_index)

    team_a_without_group = List.delete_at(team_a_groups, group_a_index)

    combo_indices = Enum.map(group_b_combo, fn {_, index} -> index end)
    combo_groups = Enum.map(group_b_combo, fn {group, _} -> group end)

    team_b_groups_without_combo =
      team_b_groups
      |> Enum.with_index()
      |> Enum.reject(fn {_, index} -> index in combo_indices end)
      |> Enum.map(fn {element, _} -> element end)

    teams
    |> Map.put(team_a_id, team_a_without_group ++ combo_groups)
    |> Map.put(team_b_id, team_b_groups_without_combo ++ [group_a])
  end

  @spec switch_group_combos_between_teams(
          team_map(),
          T.team_id(),
          [{BT.expanded_group(), non_neg_integer()}],
          T.team_id(),
          [{BT.expanded_group(), non_neg_integer()}]
        ) :: team_map()
  def switch_group_combos_between_teams(
        teams,
        team_a_id,
        group_a_combo,
        team_b_id,
        group_b_combo
      ) do
    team_a_groups = teams[team_a_id]
    team_b_groups = teams[team_b_id]

    {combo_a_groups, combo_a_indices} = Enum.unzip(group_a_combo)

    team_a_groups_without_combo =
      team_a_groups
      |> Enum.with_index()
      |> Enum.reject(fn {_, index} -> index in combo_a_indices end)
      |> Enum.map(fn {element, _} -> element end)

    {combo_b_groups, combo_b_indices} = Enum.unzip(group_b_combo)

    team_b_groups_without_combo =
      team_b_groups
      |> Enum.with_index()
      |> Enum.reject(fn {_, index} -> index in combo_b_indices end)
      |> Enum.map(fn {element, _} -> element end)

    teams
    |> Map.put(team_a_id, team_a_groups_without_combo ++ combo_b_groups)
    |> Map.put(team_b_id, team_b_groups_without_combo ++ combo_a_groups)
  end

  @spec lowest_highest_rated_teams(team_map()) ::
          {{T.team_id(), non_neg_integer()}, {T.team_id(), non_neg_integer()}}
  def lowest_highest_rated_teams(teams) do
    teams
    |> Enum.map(fn {team_id, team_groups} ->
      {team_id, sum_group_rating(team_groups)}
    end)
    |> Enum.min_max_by(fn {_team_id, rating} -> rating end)
  end

  @spec make_group_combinations([BT.expanded_group()], non_neg_integer(), boolean()) ::
          {[[{BT.expanded_group(), non_neg_integer()}]], map()}
  def make_group_combinations([], _match_member_count) do
    []
  end

  def make_group_combinations(_groups, 0) do
    []
  end

  def make_group_combinations(groups, match_member_count) do
    make_group_combinations(groups, match_member_count, false, %{})
  end

  def make_group_combinations(groups, match_member_count, include_smaller_combos) do
    make_group_combinations(groups, match_member_count, include_smaller_combos, %{})
  end

  def make_group_combinations(groups, match_member_count, include_smaller_combos, combo_memo) do
    groups_with_index = Enum.with_index(groups)
    # Find all combinations of all groups that could possibly combine to make a match

    {intial_combos, combo_memo} =
      Enum.reduce(1..match_member_count, {[], combo_memo}, fn i, {acc, memo} ->
        # This allows us to combine uneven sized groups, we will later just filter out the ones
        # that don't match the match_member_count
        group_indicies_of_size_i =
          groups_with_index
          |> Enum.filter(fn {group, _index} -> group.count <= i end)
          |> Enum.map(fn {_group, index} -> index end)

        key =
          "#{group_indicies_of_size_i |> Enum.sort() |> Enum.join("-")}:#{match_member_count - i + 1}"

        case Map.get(memo, key) do
          nil ->
            combo_res = combine(group_indicies_of_size_i, match_member_count - i + 1)
            {[combo_res | acc], Map.put(memo, key, combo_res)}

          existing_res ->
            {[existing_res | acc], memo}
        end
      end)

    res =
      intial_combos
      |> Enum.flat_map(fn group_combos -> group_combos end)
      |> Enum.filter(fn combo_of_indicies -> length(combo_of_indicies) > 0 end)
      |> Enum.uniq_by(fn combo_of_indicies ->
        combo_of_indicies
        |> Enum.map_join("-", fn i -> to_string(i) end)
      end)
      |> Enum.map(fn combo_of_indicies ->
        Enum.filter(groups_with_index, fn {_g, i} ->
          i in combo_of_indicies
        end)
      end)
      # Only keep the combinations that have the right number of total members
      |> Enum.filter(fn group_combo ->
        total_members = Enum.sum(Enum.map(group_combo, fn {group, _index} -> group.count end))

        if include_smaller_combos do
          total_members <= match_member_count
        else
          total_members == match_member_count
        end
      end)

    {res, combo_memo}
  end

  # Copied from https://github.com/seantanly/elixir-combination/blob/v0.0.3/lib/combination.ex#L1
  @spec combine(Enum.t(), non_neg_integer) :: [list]
  def combine(collection, k) when is_integer(k) and k >= 0 do
    list = Enum.to_list(collection)
    list_length = Enum.count(list)

    if k > list_length do
      []
    else
      do_combine(list, list_length, k, [], [])
    end
  end

  defp do_combine(_list, _list_length, 0, _pick_acc, _acc), do: [[]]
  # optimization
  defp do_combine(list, _list_length, 1, _pick_acc, _acc), do: list |> Enum.map(&[&1])

  defp do_combine(list, list_length, k, pick_acc, acc) do
    list
    |> Stream.unfold(fn [h | t] -> {{h, t}, t} end)
    |> Enum.take(list_length)
    |> Enum.reduce(acc, fn {x, sublist}, acc ->
      sublist_length = Enum.count(sublist)
      pick_acc_length = Enum.count(pick_acc)

      if k > pick_acc_length + 1 + sublist_length do
        # insufficient elements in sublist to generate new valid combinations
        acc
      else
        new_pick_acc = [x | pick_acc]
        new_pick_acc_length = pick_acc_length + 1

        case new_pick_acc_length do
          ^k -> [new_pick_acc | acc]
          _ -> do_combine(sublist, sublist_length, k, new_pick_acc, acc)
        end
      end
    end)
  end
end
