defmodule Teiserver.Battle.Balance.RespectAvoids do
  @moduledoc """
  A balance algorithm that tries to keep avoided players on seperate teams.

  High uncertainty players are avoid immune because we classify those as noobs and want to spread
  them evenly across teams (like split_noobs).

  Parties will have signficantly higher importance than avoids. To limit the amount of computation, the amount of
  avoids is limited for higher player counts.
  """
  alias Teiserver.Battle.Balance.BalanceTypes, as: BT
  alias Teiserver.Battle.Balance.RespectAvoidsTypes, as: RA
  alias Teiserver.Battle.Balance.BruteForceAvoid
  import Teiserver.Helper.NumberHelper, only: [format: 1]
  alias Teiserver.Account.RelationshipLib
  alias Teiserver.Config
  alias Teiserver.Battle.BalanceLib
  # If player uncertainty is greater than equal to this, that player is considered a noob
  # The lowest uncertainty rank 0 player at the time of writing this is 6.65
  @high_uncertainty 6.65
  @splitter "------------------------------------------------------"
  @per_player_avoid_limit 2

  @doc """
  Main entry point used by balance_lib
  """
  @spec perform([BT.expanded_group()], non_neg_integer(), list()) :: any()
  def perform(expanded_group, team_count, opts \\ []) do
    debug_mode? = Keyword.get(opts, :debug_mode?, false)
    initial_state = get_initial_state(expanded_group, debug_mode?)

    case should_use_algo(team_count) do
      :ok ->
        result = get_result(initial_state)
        standardise_result(result, initial_state)

      {:error, message, alternate_balancer} ->
        # Call another balancer
        result = alternate_balancer.perform(expanded_group, team_count, opts)

        new_logs =
          [
            "#{message}",
            result.logs
          ]
          |> List.flatten()

        Map.put(result, :logs, new_logs)
    end
  end

  @spec get_initial_state([BT.expanded_group()], boolean()) :: RA.state()
  def get_initial_state(expanded_group, debug_mode?) do
    players = flatten_members(expanded_group)
    parties = get_parties(expanded_group)

    noobs = get_solo_noobs(players) |> sort_noobs()
    experienced_players = get_experienced_players(players, noobs)
    experienced_player_ids = experienced_players |> Enum.map(fn x -> x.id end)
    players_in_parties_count = parties |> List.flatten() |> Enum.count()
    lobby_max_avoids = get_max_avoids(Enum.count(players), players_in_parties_count)
    avoids = get_avoids(experienced_player_ids, lobby_max_avoids, debug_mode?)

    experienced_players =
      experienced_players
      |> sort_experienced_players(avoids)
      |> Enum.with_index(fn element, index ->
        element |> Map.put(:index, index + 1)
      end)

    # top_experienced are the players we will feed into brute force algo
    # We limit to 14 players or it will take too long
    index_cut_off = 14

    top_experienced =
      experienced_players
      |> Enum.filter(fn player ->
        player.index <= index_cut_off
      end)

    bottom_experienced =
      experienced_players
      |> Enum.filter(fn player ->
        player.index > index_cut_off
      end)

    %{
      parties: parties,
      players: players,
      avoids: avoids,
      noobs: noobs,
      top_experienced: top_experienced,
      bottom_experienced: bottom_experienced,
      debug_mode?: debug_mode?,
      lobby_max_avoids: lobby_max_avoids
    }
  end

  @spec should_use_algo(integer()) ::
          :ok | {:error, String.t(), any()}
  def should_use_algo(team_count) do
    # If team count not two, then call loser_picks
    # Otherwise return :ok
    cond do
      team_count != 2 ->
        {:error, "Team count not equal to 2. Will use loser_picks algorithm instead.",
         Teiserver.Battle.Balance.LoserPicks}

      true ->
        :ok
    end
  end

  @spec standardise_result(RA.result() | RA.simple_result(), RA.state()) :: any()
  def standardise_result(result, state) do
    first_team = result.first_team
    second_team = result.second_team

    team_groups = %{
      1 => standardise_team_groups(first_team),
      2 => standardise_team_groups(second_team)
    }

    team_players = %{
      1 => standardise_team_players(first_team),
      2 => standardise_team_players(second_team)
    }

    noob_log =
      cond do
        length(state.noobs) > 0 ->
          noobs_string =
            Enum.map(state.noobs, fn x ->
              chev = Map.get(x, :rank, 0) + 1
              "#{x.name} (chev: #{chev}, σ: #{format(x.uncertainty)})"
            end)

          [
            "High uncertainty players (avoid immune):",
            noobs_string
          ]

        true ->
          "Solo new players: None"
      end

    logs =
      (get_initial_logs(state) ++
         [
           noob_log,
           @splitter,
           result.logs,
           @splitter,
           "Final result:",
           "Team 1: #{log_team(first_team)}",
           "Team 2: #{log_team(second_team)}"
         ])
      |> List.flatten()

    %{
      team_groups: team_groups,
      team_players: team_players,
      logs: logs
    }
  end

  @spec get_initial_logs(RA.state()) :: [String.t()]
  defp get_initial_logs(state) do
    max_avoids = state.lobby_max_avoids

    max_avoid_text =
      cond do
        max_avoids != nil && max_avoids <= 20 -> " (Max: #{max_avoids})"
        true -> ""
      end

    avoid_text = "Avoids considered: #{Enum.count(state.avoids)}" <> max_avoid_text
    avoid_min_hours = get_avoid_delay()
    avoid_delay_text = "Avoid min time required: #{avoid_min_hours} h"

    [
      @splitter,
      "Algorithm: respect_avoids",
      @splitter,
      "This algorithm will try and respect parties and avoids of players so long as it can keep team rating difference within certain bounds. Parties have higher importance than avoids.",
      "Recent avoids will be ignored. New players will be spread evenly across teams and cannot be avoided.",
      @splitter,
      "Lobby details:",
      "Parties: #{get_party_logs(state)}",
      avoid_delay_text,
      avoid_text,
      @splitter
    ]
  end

  defp get_party_logs(state) do
    if(Enum.count(state.parties) > 0) do
      state.parties
      |> Enum.map(fn party ->
        player_names =
          Enum.map(party, fn x ->
            get_player_name(x, state.players)
          end)

        "(#{Enum.join(player_names, ", ")})"
      end)
      |> Enum.join(", ")
    else
      "None"
    end
  end

  defp get_player_name(id, players) do
    Enum.find(players, %{name: "error"}, fn x -> x.id == id end).name
  end

  @spec log_team([RA.player()]) :: String.t()
  defp log_team(team) do
    Enum.map(team, fn x ->
      x.name
    end)
    |> Enum.reverse()
    |> Enum.join(", ")
  end

  @spec standardise_team_groups([RA.player()]) :: any()
  defp standardise_team_groups(team) do
    team
    |> Enum.map(fn x ->
      %{
        members: [x.id],
        count: 1,
        group_rating: x.rating,
        ratings: [x.rating]
      }
    end)
  end

  defp standardise_team_players(team) do
    team
    |> Enum.map(fn x ->
      x.id
    end)
  end

  # Get the most amount of avoids to be pulled from the database (per lobby)
  # For high player counts, we need a limit for performance reasons
  # For lower player counts, we have no limit
  def get_max_avoids(player_count, players_in_parties_count) do
    cond do
      # 7v7 and above
      player_count >= 14 ->
        # For 7v7 and above, if there are no parties, we pull at most 7 avoids from the database
        # For every two players in parties, we reduce the number of avoids by 1 to a minimum of 1
        # This is for performance reasons as processing parties and avoids takes time
        max(1, ((14 - players_in_parties_count) / 2) |> trunc())

      # Anything else
      true ->
        nil
    end
  end

  @spec get_parties([BT.expanded_group()]) :: [String.t()]
  def get_parties(expanded_group) do
    Enum.filter(expanded_group, fn x ->
      x[:count] >= 2
    end)
    |> Enum.map(fn y ->
      # These are ids not names
      y[:members]
    end)
  end

  @spec get_result(RA.state()) :: RA.result() | RA.simple_result()
  def get_result(state) do
    if(Enum.count(state.parties) == 0 && Enum.count(state.avoids) == 0) do
      do_simple_draft(state)
    else
      do_brute_force_and_draft(state)
    end
  end

  defp do_brute_force_and_draft(state) do
    # This is the best combo with only the top 14 experienced players
    # This means we brute force at most 14 playesr
    combo_result =
      BruteForceAvoid.get_best_combo(state.top_experienced, state.avoids, state.parties)

    # These are the remaining players who were not involved in the brute force algorithm
    remaining = state.bottom_experienced ++ state.noobs

    logs = [
      "Perform brute force with the following players to get the best score.",
      "Players: #{Enum.join(Enum.map(state.top_experienced, fn x -> x.name end), ", ")}",
      @splitter,
      "Brute force result:",
      "Team rating diff penalty: #{format(combo_result.rating_diff_penalty)}",
      "Broken party penalty: #{combo_result.broken_party_penalty}",
      "Broken avoid penalty: #{combo_result.broken_avoid_penalty}",
      "Captain rating diff penalty: #{format(combo_result.captain_diff_penalty)}",
      "Score: #{format(combo_result.score)} (lower is better)",
      @splitter,
      "Draft remaining players (ordered from best to worst).",
      "Remaining: #{Enum.join(Enum.map(remaining, fn x -> x.name end), ", ")}"
    ]

    default_acc = combo_result

    # Draft the remaining players
    Enum.reduce(remaining, default_acc, fn noob, acc ->
      picking_team = get_picking_team(acc.first_team, acc.second_team)

      Map.put(acc, picking_team, [noob | acc[picking_team]])
    end)
    |> Map.put(:logs, logs)
  end

  @spec do_simple_draft(RA.state()) :: RA.simple_result()
  defp do_simple_draft(state) do
    default_acc = %{
      first_team: [],
      second_team: []
    }

    experienced_players = state.top_experienced ++ state.bottom_experienced

    noobs = state.noobs
    sorted_players = experienced_players ++ noobs

    Enum.reduce(sorted_players, default_acc, fn x, acc ->
      picking_team = get_picking_team(acc.first_team, acc.second_team)

      Map.put(acc, picking_team, [x | acc[picking_team]])
    end)
    |> Map.put(:logs, ["Teams constructed by simple draft"])
  end

  def get_picking_team(first_team, second_team) do
    first_team_pick_priority = get_pick_priority(first_team)
    second_team_pick_priority = get_pick_priority(second_team)

    if(first_team_pick_priority > second_team_pick_priority) do
      :first_team
    else
      :second_team
    end
  end

  # Higher pick priority means that team should pick
  defp get_pick_priority(team) do
    team_rating = get_team_rating(team)
    captain_rating = get_captain_rating(team)
    # Prefer smaller rating
    rating_importance = -1
    # Prefer team with less players
    size_importance = -100
    # Prefer weaker captain
    captain_importance = -1

    # Score
    team_rating * rating_importance + length(team) * size_importance +
      captain_rating * captain_importance
  end

  defp get_captain_rating(team) do
    if Enum.count(team) > 0 do
      captain =
        Enum.max_by(team, fn x ->
          x.rating
        end)

      captain[:rating]
    else
      0
    end
  end

  defp get_team_rating(team) do
    Enum.reduce(team, 0, fn x, acc ->
      acc + x.rating
    end)
  end

  def sort_noobs(noobs) do
    # Prefer higher rank
    rank_importance = 100
    # Prefer lower uncertainty
    uncertainty_importance = -1

    Enum.sort_by(
      noobs,
      fn noob ->
        rank = Map.get(noob, :rank, 0)
        uncertainty = Map.get(noob, :uncertainty, 8.33)
        rank_importance * rank + uncertainty_importance * uncertainty
      end,
      :desc
    )
  end

  @doc """
  Converts the input to a simple list of players
  """
  @spec flatten_members([BT.expanded_group()]) :: any()
  def flatten_members(expanded_group) do
    for %{
          members: members,
          ratings: ratings,
          ranks: ranks,
          names: names,
          uncertainties: uncertainties,
          count: count
        } <- expanded_group,
        # Zipping will create binary tuples from 2 lists
        {id, rating, rank, name, uncertainty} <-
          Enum.zip([members, ratings, ranks, names, uncertainties]),
        # Create result value
        do: %{
          rating: adjusted_rating(rating, uncertainty, rank),
          name: name,
          id: id,
          uncertainty: uncertainty,
          rank: rank,
          in_party?:
            cond do
              count <= 1 -> false
              true -> true
            end
        }
  end

  # This balance algorithm will use an adjusted rating for newish players
  # This will not be displayed in chobby ui or player list; it's only used for balance
  # It will be used when calculating team deviation
  defp adjusted_rating(rating, uncertainty, rank) do
    if(is_newish_player?(rank, uncertainty)) do
      # For newish players we assume they are the worst in the lobby e.g. 0 match rating and
      # then they converge to their true rating over time
      # Once their uncertainty is low enough, we fully trust their rating
      {_skill, starting_uncertainty} = Openskill.rating()

      uncertainty_cutoff = @high_uncertainty

      min(
        1,
        (starting_uncertainty - uncertainty) /
          (starting_uncertainty - uncertainty_cutoff)
      ) * rating
    else
      rating
    end
  end

  @spec get_avoids([any()], number(), boolean()) :: [String.t()]
  def get_avoids(player_ids, lobby_max_avoids, debug_mode? \\ false) do
    cond do
      debug_mode? ->
        RelationshipLib.get_lobby_avoids(player_ids, lobby_max_avoids, @per_player_avoid_limit)

      true ->
        avoid_min_hours = get_avoid_delay()

        RelationshipLib.get_lobby_avoids(
          player_ids,
          lobby_max_avoids,
          @per_player_avoid_limit,
          avoid_min_hours
        )
    end
  end

  @spec get_avoid_delay() :: number()
  defp get_avoid_delay() do
    Config.get_site_config_cache("lobby.Avoid min hours required")
  end

  ## Gets experienced players
  def get_experienced_players(players, noobs) do
    Enum.filter(players, fn player ->
      !Enum.any?(noobs, fn noob ->
        noob.name == player.name
      end)
    end)
  end

  ## Players that are in parties or avoids (in either direction) are at the front, then sort by rating
  @spec sort_experienced_players([RA.player()], [[number()]]) :: [RA.player()]
  def sort_experienced_players(experienced_players, avoids) do
    flat_avoids = avoids |> List.flatten()

    experienced_players
    |> Enum.sort_by(
      fn player ->
        is_in_avoid_list? =
          Enum.any?(flat_avoids, fn id ->
            id == player.id
          end)

        avoid_relevance =
          case is_in_avoid_list? do
            true -> 100
            false -> 0
          end

        party_relevance =
          case player.in_party? do
            true -> 1000
            false -> 0
          end

        player.rating + avoid_relevance + party_relevance
      end,
      :desc
    )
  end

  # Noobs have high uncertainty and chev 1,2,3
  @spec get_solo_noobs([RA.player()]) :: any()
  def get_solo_noobs(players) do
    Enum.filter(players, fn player ->
      is_newish_player?(player.rank, player.uncertainty) && !player.in_party?
    end)
  end

  def is_newish_player?(rank, uncertainty) do
    if BalanceLib.new_players_start_at_zero?() do
      # Since new players start at zero, we shouldn't need to treat them special
      # We can trust their rating since it won't be inflated
      false
    else
      # It is possible that someone has high uncertainty due to
      # playing unranked, playing PvE, or playing a different game mode e.g. 1v1
      # If they have many hours i.e. chev 4 = 100 hours, we will not consider them newish
      uncertainty >= @high_uncertainty && rank <= 2
    end
  end
end
