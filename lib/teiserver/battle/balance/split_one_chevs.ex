defmodule Teiserver.Battle.Balance.SplitOneChevs do
  alias Teiserver.CacheUser

  @moduledoc """
    This balance algorithm first sorts the users by visible OS (match rating) descending. Then all rank=0 (one chevs) will be placed at the bottom of this sorted list.

    Next a team will be chosen to be the picking team. The picking team is the team with the least amount of players. If tied, then the team with the lowest total rating.

    Next the picking team will pick the player at the top of the sorted list.

    This is repeated until all players are chosen.

    This algorithm completely ignores parties.

  """

  @doc """
  Input:
  expanded_group:
  [
      %{count: 2, members: [1, 4], group_rating: 13, ratings: [8, 5]},
      %{count: 1, members: [2], group_rating: 6, ratings: [6]},
      %{count: 1, members: [3], group_rating: 7, ratings: [7]}
  ]
  """
  def perform(expanded_group, team_count, _opts \\ []) do
    members = flatten_members(expanded_group) |> sort_members()
    %{teams: teams, logs: logs} = assign_teams(members, team_count)
    standardise_result(teams, logs)
  end

  @doc """
  Input:
  expanded_group:
  [
      %{count: 2, members: [1, 4], group_rating: 13, ratings: [8, 5]},
      %{count: 1, members: [2], group_rating: 6, ratings: [6]},
      %{count: 1, members: [3], group_rating: 7, ratings: [7]}
  ]

  Output:  [
  %{rating: 8, member_id: 1},
  %{rating: 5, member_id: 4},
  %{rating: 6, member_id: 2},
  %{rating: 7, member_id: 3}
  ]
  """
  def flatten_members(expanded_group) do
    for %{members: members, ratings: ratings} <- expanded_group,
        # Zipping will create binary tuples from 2 lists
        {id, rating} <- Enum.zip(members, ratings),
        # Create result value
        rank = get_rank(id),
        do: %{member_id: id, rating: rating, rank: rank}
  end

  def get_rank(member_id) do
    CacheUser.calculate_rank(member_id, "Playtime")
  end

  @doc """
  members=
  [
             %{rating: 8, rank: 4, member_id: 100},
             %{rating: 5, rank: 0, member_id: 4},
             %{rating: 6, rank: 0, member_id: 2},
             %{rating: 17, rank: 0, member_id: 3}
           ]

  Output: Members will be sorted by rank descending; however, rank=0 players will always be last
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
  member_list: A sorted list of members e.g.
  [
  %{rating: 8, member_id: 1},
  %{rating: 5, member_id: 4},
  %{rating: 6, member_id: 2},
  %{rating: 7, member_id: 3}
  ]

  Returns %{teams:teams, logs:logs}
  """
  def assign_teams(member_list, number_of_teams) do
    default_acc = %{teams: create_empty_teams(number_of_teams), logs: []}

    Enum.reduce(member_list, default_acc, fn x, acc ->
      picking_team = get_picking_team(acc.teams)
      update_picking_team = Map.merge(picking_team, %{members: [x | picking_team.members]})
      new_log = "User #{x.member_id} picked for Team #{picking_team.team_id}"

      %{
        teams: [update_picking_team | get_non_picking_teams(acc.teams, picking_team)],
        logs: acc.logs ++ [new_log]
      }
    end)
  end

  @spec create_empty_teams(any()) :: any()
  def create_empty_teams(count) do
    for i <- 1..count,
        do: %{team_id: i, members: []}
  end

  @spec get_picking_team(any()) :: any()
  def get_picking_team(teams) do
    default_picking_team = Enum.at(teams, 0)

    Enum.reduce(teams, default_picking_team, fn x, acc ->
      # Team is picker if it has least members
      if(length(x.members) < length(acc.members)) do
        x
      else
        # Team is picker if it is tied for least and has lower team rating
        if(
          length(x.members) == length(acc.members) && get_team_rating(x) < get_team_rating(acc)
        ) do
          x
        else
          acc
        end
      end
    end)
  end

  def get_non_picking_teams(teams, picking_team) do
    Enum.filter(teams, fn x -> x.team_id != picking_team.team_id end)
  end

  def get_team_rating(team) do
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
  def standardise_result(teams, logs) do
    team_groups = standardise_team_groups(teams)

    %{
      team_groups: team_groups,
      team_players: standardise_team_players(teams),
      logs: logs
    }
  end

  def standardise_team_groups(raw_input) do
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
  def standardise_members(members) do
    for %{rating: rating, member_id: member_id} <- members,
        do: %{members: [member_id], count: 1, group_rating: rating, ratings: [rating]}
  end

  def standardise_team_players(raw_input) do
    Map.new(raw_input, fn x -> {x.team_id, standardise_member_ids(x.members)} end)
  end

  def standardise_member_ids(members) do
    for %{member_id: member_id} <- members,
        do: member_id
  end
end
