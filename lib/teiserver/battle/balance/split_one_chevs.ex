defmodule Teiserver.Battle.Balance.SplitOneChevs do
  @moduledoc """
  Overview:
  The goal of this algorithm is to mimic how a human would draft players given the visual information in a lobby.
  Humans will generally avoid drafting overrated new players.

  Details:
  The team with the least amount of players will pick an unchosen player. If there are multiple teams tied for
  the lowest player count, then the team with the lowest match rating picks.

  Your team will prefer 3Chev+ players with high OS. If your team must pick a 1-2Chev player,
  it will prefer lower uncertainty.

  This is repeated until all players are chosen.

  This algorithm completely ignores parties.

  """
  alias Teiserver.Battle.Balance.SplitOneChevsTypes, as: ST
  alias Teiserver.Battle.Balance.BalanceTypes, as: BT
  import Teiserver.Helper.NumberHelper, only: [format: 1]

  @splitter "---------------------------"

  @doc """
  Main entry point used by balance_lib
  See split_one_chevs_internal_test.exs for sample input
  """
  @spec perform([BT.expanded_group()], non_neg_integer(), list()) :: any()
  def perform(expanded_group, team_count, opts \\ []) do
    if has_enough_noobs?(expanded_group) do
      members = flatten_members(expanded_group) |> sort_members()
      %{teams: teams, logs: logs} = assign_teams(members, team_count)
      standardise_result(teams, logs)
    else
      # Not enough noobs; so call another balancer
      result = Teiserver.Battle.Balance.LoserPicks.perform(expanded_group, team_count, opts)

      new_logs =
        ["Not enough noobs; calling another balancer.", @splitter, result.logs]
        |> List.flatten()

      Map.put(result, :logs, new_logs)
    end
  end

  @doc """
  For now this simply checks there is at least a single 1chev or a single 2chev.
  However we could modify this in the future to be more complicated e.g. at least a single 1chev
  or at least two, 2chevs.
  """
  @spec has_enough_noobs?([BT.expanded_group()]) :: bool()
  def has_enough_noobs?(expanded_group) do
    ranks =
      Enum.map(expanded_group, fn x ->
        Map.get(x, :ranks, [])
      end)
      |> List.flatten()

    Enum.any?(ranks, fn x ->
      x < 2
    end)
  end

  @doc """
  Remove all groups/parties and treats everyone as solo players. This algorithm doesn't support parties.
  See split_one_chevs_internal_test.exs for sample input
  """
  def flatten_members(expanded_group) do
    for %{
          members: members,
          ratings: ratings,
          ranks: ranks,
          names: names,
          uncertainties: uncertainties
        } <- expanded_group,
        # Zipping will create binary tuples from 2 lists
        {id, rating, rank, name, uncertainty} <-
          Enum.zip([members, ratings, ranks, names, uncertainties]),
        # Create result value
        do: %{
          member_id: id,
          rating: rating,
          rank: rank,
          name: name,
          uncertainty: uncertainty
        }
  end

  @doc """
  Experienced players will be on top followed by noobs.
  Experienced players are 3+ Chevs. They will be sorted with higher OS on top.
  Noobs are 1-2 Chevs. They will be sorted with lower uncertainty on top.
  """
  def sort_members(members) do
    non_noobs = Enum.filter(members, fn x -> x.rank >= 2 end)
    noobs = Enum.filter(members, fn x -> x.rank < 2 end)

    [
      Enum.sort_by(non_noobs, fn x -> x.rating end, &>=/2),
      Enum.sort_by(noobs, fn x -> x.uncertainty end, &<=/2)
    ]
    |> List.flatten()
  end

  @doc """
  Assigns teams using algorithm defined in moduledoc
  See split_one_chevs_internal_test.exs for sample input
  """
  def assign_teams(member_list, number_of_teams) do
    default_acc = %{
      teams: create_empty_teams(number_of_teams),
      logs: [
        "Algorithm: split_one_chevs",
        @splitter,
        "Your team will try and pick 3Chev+ players first, with preference for higher OS. If 1-2Chevs are the only remaining players, then lower uncertainty is preferred.",
        @splitter
      ]
    }

    Enum.reduce(member_list, default_acc, fn x, acc ->
      picking_team = get_picking_team(acc.teams)
      update_picking_team = Map.merge(picking_team, %{members: [x | picking_team.members]})
      username = x.name

      new_log =
        "#{username} (#{format(x.rating)}, σ: #{format(x.uncertainty)}, Chev: #{x.rank + 1}) picked for Team #{picking_team.team_id}"

      %{
        teams: [update_picking_team | get_non_picking_teams(acc.teams, picking_team)],
        logs: acc.logs ++ [new_log]
      }
    end)
  end

  def create_empty_teams(count) do
    for i <- 1..count,
        do: %{team_id: i, members: []}
  end

  defp get_picking_team(teams) do
    default_picking_team = Enum.at(teams, 0)

    Enum.reduce(teams, default_picking_team, fn x, acc ->
      cond do
        # Team is picker if it has least members
        length(x.members) < length(acc.members) -> x
        # Team is picker if it is tied for least and has lower team rating
        length(x.members) == length(acc.members) && get_team_rating(x) < get_team_rating(acc) -> x
        true -> acc
      end
    end)
  end

  defp get_non_picking_teams(teams, picking_team) do
    Enum.filter(teams, fn x -> x.team_id != picking_team.team_id end)
  end

  defp get_team_rating(team) do
    Enum.reduce(team.members, 0, fn x, acc ->
      acc + x.rating
    end)
  end

  @spec standardise_result([ST.team()], [String.t()]) :: any
  defp standardise_result(teams, logs) do
    team_groups = standardise_team_groups(teams)

    %{
      team_groups: team_groups,
      team_players: standardise_team_players(teams),
      logs: logs
    }
  end

  defp standardise_team_groups(raw_input) do
    Map.new(raw_input, fn x -> {x.team_id, standardise_members(x.members)} end)
  end

  @spec standardise_members([ST.member()]) :: [BT.group()]
  defp standardise_members(members) do
    for %{rating: rating, member_id: member_id} <- members,
        do: %{members: [member_id], count: 1, group_rating: rating, ratings: [rating]}
  end

  defp standardise_team_players(raw_input) do
    Map.new(raw_input, fn x -> {x.team_id, standardise_member_ids(x.members)} end)
  end

  defp standardise_member_ids(members) do
    Enum.map(members, fn member -> member[:member_id] end)
  end
end
