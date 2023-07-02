defmodule Teiserver.Battle.BalanceUtil do
  @moduledoc """
  Documentation for BalanceUtil.
  """

  alias Central.Config

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

  @type rating_value() :: float()
  @type player_group() :: %{T.userid() => rating_value()}
  @type expanded_group() :: %{
          members: [T.userid()],
          names: [charlist()],
          ratings: [rating_value()],
          group_rating: rating_value(),
          count: non_neg_integer()
        }
  @type expanded_group_or_pair() :: expanded_group() | {expanded_group(), expanded_group()}
  @type team_map() :: %{T.team_id() => [expanded_group()]}

  # These are default values and can be overridden as part of the call to create_balance()
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

  # Given a list of groups, return the combined number of members
  @spec sum_group_membership_size([expanded_group()]) :: non_neg_integer()
  def sum_group_membership_size([]), do: 0

  def sum_group_membership_size(groups) do
    groups
    |> Enum.map(fn %{count: count} -> count end)
    |> Enum.sum()
  end

  # Given a list of groups, return the combined rating (summed)
  @spec sum_group_rating([expanded_group()]) :: non_neg_integer()
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
  def max_team_rating_difference([]) do 0 end
  def max_team_rating_difference([_team]) do 0 end
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

  @spec sort_groups_by_rating([expanded_group()]) :: [expanded_group()]
  def sort_groups_by_rating(groups) do
    Enum.sort_by(
      groups,
      fn %{group_rating: rating} -> rating end,
      :desc)
  end

  @spec sort_groups_by_count([expanded_group()]) :: [expanded_group()]
  def sort_groups_by_count(groups) do
    Enum.sort_by(
      groups,
      fn %{count: count} -> count end,
      :desc)
  end

  @spec unwind_teams_to_groups(team_map()) :: [expanded_group()]
  def unwind_teams_to_groups(teams) do
    Enum.flat_map(teams, fn {_k, team_groups} -> team_groups end)
  end

  @spec get_parties([expanded_group()]) :: [expanded_group()]
  def get_parties(groups) do
    groups
    |> Enum.filter(fn group -> group.count > 1 end)
  end

  @spec count_parties([expanded_group()]) :: non_neg_integer()
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
    |> Enum.map(fn {_id, groups} -> sum_group_rating(groups) / sum_group_membership_size(groups) end)
  end

  def team_stddevs(teams) do
    teams
    |> Enum.map(fn {_id, groups} -> Statistics.stdev(Enum.flat_map(groups, fn group -> group.ratings end)) end)
  end

  @spec has_parties(team_map()) :: boolean()
  def has_parties(teams) do
    teams
    |> Enum.any?(fn {_k, team_groups} ->
      Enum.any?(team_groups, fn %{count: count} -> count > 1 end) end)
  end

  @spec replace_team_group_at_index(team_map(), T.team_id(), non_neg_integer(), expanded_group()) :: team_map()
  def replace_team_group_at_index(teams, team_id, group_index, group) do
    Map.put(teams, team_id, List.replace_at(teams[team_id], group_index, group))
  end

  @spec switch_group_pair_between_teams(team_map(), T.team_id(), non_neg_integer(), T.team_id(), non_neg_integer()) :: team_map()
  def switch_group_pair_between_teams(
    teams,
    team_a_id,
    group_a_index,
    team_b_id,
    group_b_index) do
    team_a_groups = teams[team_a_id]
    group_a = Enum.at(team_a_groups, group_a_index)
    team_b_groups = teams[team_b_id]
    group_b = Enum.at(team_b_groups, group_b_index)

    replace_team_group_at_index(teams, team_a_id, group_a_index, group_b)
    |> replace_team_group_at_index(team_b_id, group_b_index, group_a)
  end

  @spec switch_group_pair_between_teams(team_map(), T.team_id(), non_neg_integer(), T.team_id(), [{expanded_group(), non_neg_integer()}]) :: team_map()
  def switch_group_with_combo_between_teams(
    teams,
    team_a_id,
    group_a_index,
    team_b_id,
    group_b_combo) do
    team_a_groups = teams[team_a_id]
    team_b_groups = teams[team_b_id]
    group_a = Enum.at(team_a_groups, group_a_index)

    team_a_without_group = List.delete_at(team_a_groups, group_a_index)

    combo_indices = Enum.map(group_b_combo, fn {_, index} -> index end)
    combo_groups = Enum.map(group_b_combo, fn {group, _} -> group end)
    team_b_groups_without_combo = team_b_groups
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
    [{expanded_group(), non_neg_integer()}],
    T.team_id(),
    [{expanded_group(), non_neg_integer()}]) :: team_map()
  def switch_group_combos_between_teams(
    teams,
    team_a_id,
    group_a_combo,
    team_b_id,
    group_b_combo) do
    team_a_groups = teams[team_a_id]
    team_b_groups = teams[team_b_id]

    {combo_a_groups, combo_a_indices} = Enum.unzip(group_a_combo)
    team_a_groups_without_combo = team_a_groups
    |> Enum.with_index()
    |> Enum.reject(fn {_, index} -> index in combo_a_indices end)
    |> Enum.map(fn {element, _} -> element end)

    {combo_b_groups, combo_b_indices} = Enum.unzip(group_b_combo)
    team_b_groups_without_combo = team_b_groups
    |> Enum.with_index()
    |> Enum.reject(fn {_, index} -> index in combo_b_indices end)
    |> Enum.map(fn {element, _} -> element end)

    teams
    |> Map.put(team_a_id, team_a_groups_without_combo ++ combo_b_groups)
    |> Map.put(team_b_id, team_b_groups_without_combo ++ combo_a_groups)
  end

  @spec lowest_highest_rated_teams(team_map()) :: {{T.team_id(), non_neg_integer()}, {T.team_id(), non_neg_integer()}}
  def lowest_highest_rated_teams(teams) do
    teams
    |> Enum.map(fn {team_id, team_groups} ->
      {team_id, sum_group_rating(team_groups)}
    end)
    |> Enum.min_max_by(fn {_team_id, rating} -> rating end)
  end

  @spec make_group_combinations([expanded_group()], non_neg_integer(), boolean()) :: {[[{expanded_group(), non_neg_integer()}]], map()}
  def make_group_combinations([], _match_member_count) do [] end
  def make_group_combinations(_groups, 0) do [] end
  def make_group_combinations(groups, match_member_count) do make_group_combinations(groups, match_member_count, false, %{}) end
  def make_group_combinations(groups, match_member_count, include_smaller_combos) do make_group_combinations(groups, match_member_count, include_smaller_combos, %{}) end
  def make_group_combinations(groups, match_member_count, include_smaller_combos, combo_memo) do
    groups_with_index = Enum.with_index(groups)
    # Find all combinations of all groups that could possibly combine to make a match

    {intial_combos, combo_memo} = Enum.reduce(1..match_member_count, {[], combo_memo}, fn i, {acc, memo} ->
      # This allows us to combine uneven sized groups, we will later just filter out the ones
      # that don't match the match_member_count
      group_indicies_of_size_i = groups_with_index
      |> Enum.filter(fn {group, _index} -> group.count <= i end)
      |> Enum.map(fn {_group, index} -> index end)

      key = "#{group_indicies_of_size_i |> Enum.sort |> Enum.join("-")}:#{match_member_count - i + 1}"

      case Map.get(memo, key) do
        nil ->
          combo_res = combine(group_indicies_of_size_i, match_member_count - i + 1)
          {[combo_res | acc], Map.put(memo, key, combo_res)}
        existing_res ->
          {[existing_res | acc], memo}
      end
    end)

    res = intial_combos
    |> Enum.flat_map(fn group_combos -> group_combos end)
    |> Enum.filter(fn combo_of_indicies -> length(combo_of_indicies) > 0 end)
    |> Enum.uniq_by(fn combo_of_indicies -> combo_of_indicies
      |> Enum.map(fn i -> to_string(i) end)
      |> Enum.join("-")
    end)
    |> Enum.map(fn combo_of_indicies ->
      Enum.filter(groups_with_index, fn {_g, i} ->
        i in combo_of_indicies
      end)
    end)
    # Only keep the combinations that have the right number of total members
    |> Enum.filter(
      fn group_combo ->
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
  @spec combine(Enum.t, non_neg_integer) :: [list]
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
  defp do_combine(list, _list_length, 1, _pick_acc, _acc), do: list |> Enum.map(&([&1])) # optimization
  defp do_combine(list, list_length, k, pick_acc, acc) do
    list
    |> Stream.unfold(fn [h | t] -> {{h, t}, t} end)
    |> Enum.take(list_length)
    |> Enum.reduce(acc, fn {x, sublist}, acc ->
      sublist_length = Enum.count(sublist)
      pick_acc_length = Enum.count(pick_acc)
      if k > pick_acc_length + 1 + sublist_length do
        acc # insufficient elements in sublist to generate new valid combinations
      else
        new_pick_acc = [x | pick_acc]
        new_pick_acc_length = pick_acc_length + 1
        case new_pick_acc_length do
          ^k -> [new_pick_acc | acc]
          _  -> do_combine(sublist, sublist_length, k, new_pick_acc, acc)
        end
      end
    end)
  end
end
