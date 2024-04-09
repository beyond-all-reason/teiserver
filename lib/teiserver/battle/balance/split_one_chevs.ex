defmodule Teiserver.Battle.Balance.SplitOneChevs do
  @moduledoc """
    This balance algorithm first sorts the users by visible OS (match rating) descending. Then all rank=0 (one chevs) will be placed at the bottom of this sorted list.

    Next a team will be chosen to be the picking team. The picking team is the team with the least amount of players. If tied, then the team with the lowest total rating.

    Next the picking team will pick the player at the top of the sorted list.

    This is repeated until all players are chosen.

    This algorithm completely ignores parties.

  """

  @doc """
  Main entry point used by balance_lib
  See split_one_chevs_internal_test.exs for sample input
  """
  def perform(expanded_group, team_count, _opts \\ []) do
    members = flatten_members(expanded_group) |> sort_members()
    %{teams: teams, logs: logs} = assign_teams(members, team_count)
    standardise_result(teams, logs)
  end

  @doc """
  Remove all groups/parties and treats everyone as solo players. This algorithm doesn't support parties.
  See split_one_chevs_internal_test.exs for sample input
  """
  def flatten_members(expanded_group) do
    for %{members: members, ratings: ratings, ranks: ranks, names: names} <- expanded_group,
        # Zipping will create binary tuples from 2 lists
        {id, rating, rank, name} <- Enum.zip([members, ratings, ranks, names]),
        # Create result value
        do: %{member_id: id, rating: rating, rank: rank, name: name}
  end

  @doc """
  Sorts members by rating but puts one chevs at the bottom
  See split_one_chevs_internal_test.exs for sample input
  """
  def sort_members(members) do
    non_noobs = Enum.filter(members, fn x -> x.rank != 0 end)
    noobs = Enum.filter(members, fn x -> x.rank == 0 end)

    [
      Enum.sort_by(non_noobs, fn x -> x.rating end, &>=/2),
      Enum.sort_by(noobs, fn x -> x.rating end, &>=/2)
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
      logs: ["Begin split_one_chevs balance"]
    }

    Enum.reduce(member_list, default_acc, fn x, acc ->
      picking_team = get_picking_team(acc.teams)
      update_picking_team = Map.merge(picking_team, %{members: [x | picking_team.members]})
      username = x.name
      new_log = "#{username} (Chev: #{x.rank + 1}) picked for Team #{picking_team.team_id}"

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

  @doc """
  teams=
     [
             %{
               members: [
                 %{rating: 17, rank: 0, member_id: 3},
                 %{rating: 8, rank: 4, member_id: 100}
               ],
               team_id: 1
             },
             %{
               members: [
                 %{rating: 6, rank: 0, member_id: 2},
                 %{rating: 5, rank: 0, member_id: 4}
               ],
               team_id: 2
             }
           ]
  """
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

  @doc """
  members=
  [
                 %{rating: 6, rank: 0, member_id: 2},
                 %{rating: 5, rank: 0, member_id: 4}
               ]
  output= [
                 %{members: [2], count: 1, group_rating: 6, ratings: [6]},
                 %{members: [4], count: 1, group_rating: 5, ratings: [5]}
               ]
  """
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
