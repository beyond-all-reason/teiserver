defmodule Teiserver.Battle.Balance.LoserPicks do
  @moduledoc """
  1: Dealing with parties
    - Go through all groups of 2 or more members and combine their ratings to create one rating for the group
    - If the group can be paired against a group of equal strength or if any of the remaining solo players can be combined to form a group of sufficiently equal strength, the original group remains intact
    - Any groups that cannot be matched against a suitable group will be broken into solo players and balanced as such

  2: Placing paired groups
    - Each pairing of groups are iterated through and assigned to opposite teams
    - The team with the lowest combined rating picks first and selects the highest rated group

  3: Solo players
    - As long as there are players left to place
    - Whichever team with the lowest combined rating and is not full picks next
    - Said team always picks the highest rated group available
  """

  # Alias the types
  alias Teiserver.Account
  alias Teiserver.Battle.BalanceLib
  alias Teiserver.Battle.Balance.BalanceTypes, as: BT
  import Teiserver.Helper.NumberHelper, only: [round: 2]

  @type algorithm_state :: %{
          teams: map,
          logs: list,
          solo_players: list,
          opts: list
        }

  @doc """
  Each round the team with the lowest score picks, if a team has the maximum number of players
  they are not allowed to continue picking.

  groups is a list of tuples: {members, rating, member_count}
  """
  @spec perform([BT.expanded_group_or_pair()], non_neg_integer(), list()) :: BT.algorithm_result()
  def perform(raw_groups, team_count, opts) do
    teams =
      Range.new(1, team_count || 1)
      |> Map.new(fn i ->
        {i, []}
      end)

    # Now we have a list of groups, we need to work out which groups we're going to keep
    # we want to create partner groups but we're only going to do this in a 2 team game
    # because in a team ffa it'll be very problematic
    solo_players =
      raw_groups
      |> Enum.filter(fn %{count: count} -> count == 1 end)

    groups =
      raw_groups
      |> Enum.filter(fn %{count: count} -> count > 1 end)

    {group_pairs, solo_players, group_logs} =
      BalanceLib.matchup_groups(groups, solo_players, opts ++ [team_count: team_count])

    # We now need to sort the solo players by rating
    solo_players =
      solo_players
      |> Enum.sort_by(fn %{group_rating: rating} -> rating end, &>=/2)

    total_members =
      raw_groups
      |> Enum.map(fn
        {%{count: count1}, %{count: count2}} ->
          count1 + count2

        %{count: count} ->
          count

        group_list ->
          group_list
          |> Enum.map(fn g -> g.count end)
          |> Enum.sum()
      end)
      |> Enum.sum()

    max_teamsize = (total_members / Enum.count(teams)) |> :math.ceil() |> round()

    state = %{
      teams: teams,
      logs: group_logs,
      solo_players: solo_players,
      group_pairs: group_pairs,
      max_teamsize: max_teamsize,
      remaining_picks: group_pairs ++ solo_players,
      opts: opts
    }

    do_loser_picks(state)
  end

  @spec do_loser_picks(algorithm_state) :: BT.algorithm_result()
  defp do_loser_picks(%{remaining_picks: []} = state), do: state

  # defp do_loser_picks([picked | remaining_groups], teams, max_teamsize, logs, opts) do
  defp do_loser_picks(%{remaining_picks: [picked | remaining_picks]} = state) do
    team_skills =
      state.teams
      |> Enum.reject(fn {_team_number, member_groups} ->
        size = BalanceLib.sum_group_membership_size(member_groups)
        size >= state.max_teamsize
      end)
      |> Enum.map(fn {team_number, member_groups} ->
        score = BalanceLib.sum_group_rating(member_groups)

        {score, team_number}
      end)
      |> Enum.sort()

    case picked do
      # Single player
      %{count: 1} ->
        current_team =
          if state.opts[:shuffle_first_pick] do
            # Filter out any team with a higher rating than the first
            low_rating = hd(team_skills) |> elem(0)

            team_skills
            |> Enum.reject(fn {rating, _id} -> rating > low_rating end)
            |> Enum.shuffle()
            |> hd
            |> elem(1)
          else
            hd(team_skills)
            |> elem(1)
          end

        new_team = [picked | state.teams[current_team]]
        new_teams_map = Map.put(state.teams, current_team, new_team)

        names =
          picked.members
          |> Enum.map_join(", ", fn userid -> Account.get_username_by_id(userid) || userid end)

        new_total = (hd(team_skills) |> elem(0)) + picked.group_rating

        new_logs =
          state.logs ++
            [
              "Picked #{names} for team #{current_team}, adding #{round(picked.group_rating, 2)} points for new total of #{round(new_total, 2)}"
            ]

        do_loser_picks(%{
          state
          | remaining_picks: remaining_picks,
            teams: new_teams_map,
            logs: new_logs
        })

      # Groups, so we just merge a bunch of them into teams
      groups ->
        # Generate new team map
        new_teams_map =
          team_skills
          |> Enum.zip(groups)
          |> Map.new(fn {{_points, team_number}, group} ->
            team = state.teams[team_number] || []
            {team_number, [group | team]}
          end)

        # Generate logs
        extra_logs =
          team_skills
          |> Enum.zip(groups)
          |> Enum.map(fn {{points, team_number}, group} ->
            names =
              group.members
              |> Enum.map_join(", ", fn userid -> Account.get_username_by_id(userid) || userid end)

            new_team_total = points + group.group_rating

            "Group picked #{names} for team #{team_number}, adding #{round(group.group_rating, 2)} points for new total of #{round(new_team_total, 2)}"
          end)

        new_logs = state.logs ++ extra_logs

        do_loser_picks(%{
          state
          | remaining_picks: remaining_picks,
            teams: new_teams_map,
            logs: new_logs
        })
    end
  end
end
