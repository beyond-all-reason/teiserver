defmodule Teiserver.Battle.Balance.RespectAvoids do
  @moduledoc """
  A balance algorithm that tries to keep avoided players on seperate teams.

  High uncertainty players are avoid immune because we classify those as noobs and want to spread
  them evenly across teams (like split_noobs).

  Parties are ignored. However, if nobody is avoiding anybody in this lobby, we call a different
  balance algorithm that supports parties.
  """
  alias Teiserver.Battle.Balance.BalanceTypes, as: BT
  alias Teiserver.Battle.Balance.RespectAvoidsTypes, as: AP
  alias Teiserver.Battle.Balance.BruteForceAvoid
  import Teiserver.Helper.NumberHelper, only: [format: 1]
  alias Teiserver.Account.RelationshipLib
  alias Teiserver.Battle.Balance.SplitNoobs

  @splitter "------------------------------------------------------"

  @doc """
  Main entry point used by balance_lib
  """
  @spec perform([BT.expanded_group()], non_neg_integer(), list()) :: any()
  def perform(expanded_group, team_count, opts \\ []) do
    is_ranked? = Keyword.get(opts, :is_ranked?, true)
    debug_mode? = Keyword.get(opts, :debug_mode?, false)
    initial_state = get_initial_state(expanded_group, is_ranked?, debug_mode?)

    case should_use_algo(initial_state, team_count) do
      :ok ->
        result = get_result(initial_state)
        standardise_result(result, initial_state)

      {:error, message, alternate_balancer} ->
        # Call another balancer
        result =
          case alternate_balancer do
            "split_noobs" ->
              Teiserver.Battle.Balance.SplitNoobs.perform(expanded_group, team_count, opts)

            _ ->
              Teiserver.Battle.Balance.LoserPicks.perform(expanded_group, team_count, opts)
          end

        new_logs =
          (get_initial_logs(initial_state) ++
             [
               "#{message} Will use #{alternate_balancer} algorithm instead.",
               @splitter,
               result.logs
             ])
          |> List.flatten()

        Map.put(result, :logs, new_logs)
    end
  end

  @spec should_use_algo(AP.state(), integer()) ::
          :ok | {:error, String.t(), String.t()}
  def should_use_algo(initial_state, team_count) do
    has_avoids? = Enum.count(initial_state.avoids) > 0

    # If team count not two, then call loser_picks
    # If no avoids, then call split_noobs if there exists noobs or loser_picks if no noobs
    # Otherwise return :ok
    cond do
      team_count != 2 ->
        {:error, "Team count not equal to 2.", "loser_picks"}

      !has_avoids? ->
        msg = "Nobody is avoiding any other player."

        case Enum.count(initial_state.noobs) > 0 do
          true -> {:error, msg, "split_noobs"}
          false -> {:error, msg, "loser_picks"}
        end

      true ->
        :ok
    end
  end

  @spec standardise_result(AP.result() | AP.simple_result(), AP.state()) :: any()
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
          "New players: None"
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

  defp get_initial_logs(state) do
    avoid_text =
      case state.debug_mode? do
        false -> "Has avoids: #{Enum.count(state.avoids) > 0}"
        true -> "Number of avoids: #{Enum.count(state.avoids)}"
      end

    [
      @splitter,
      "Algorithm: respect_avoids",
      @splitter,
      "This algorithm will try and respect avoids of players so long as it can keep team rating difference within certain bounds. Parties will be ignored if there is at least one player avoiding another player.",
      "If the game is ranked, only avoids that are at least 24h old will be respected.",
      "New players will be spread evenly across teams and cannot be avoided.",
      @splitter,
      "Lobby details:",
      "Ranked: #{state.is_ranked?}",
      avoid_text,
      "Has parties: #{state.has_parties?}",
      @splitter
    ]
  end

  @spec log_team([AP.player()]) :: String.t()
  defp log_team(team) do
    Enum.map(team, fn x ->
      x.name
    end)
    |> Enum.reverse()
    |> Enum.join(", ")
  end

  @spec standardise_team_groups([AP.player()]) :: any()
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

  @spec get_initial_state([BT.expanded_group()], boolean(), boolean()) :: AP.state()
  def get_initial_state(expanded_group, is_ranked?, debug_mode?) do
    players = flatten_members(expanded_group)
    has_parties? = has_parties?(expanded_group)

    player_ids =
      players
      |> Enum.map(fn player ->
        player.id
      end)

    avoids = get_avoids(player_ids, is_ranked?, debug_mode?)
    noobs = get_noobs(players) |> sort_noobs()

    experienced_players =
      get_experienced_players(players, noobs, avoids)
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
      players: players,
      avoids: avoids,
      noobs: noobs,
      top_experienced: top_experienced,
      bottom_experienced: bottom_experienced,
      is_ranked?: is_ranked?,
      has_parties?: has_parties?,
      debug_mode?: debug_mode?
    }
  end

  @spec get_result(AP.state()) :: AP.result()
  def get_result(state) do
    # This is the best combo with only the top 14 experienced players
    # This means we brute force at most 14 playesr
    combo_result = BruteForceAvoid.get_best_combo(state.top_experienced, state.avoids)
    # These are the remaining players who were not involved in the brute force algorithm
    remaining = state.bottom_experienced ++ state.noobs

    logs = [
      "Perform brute force with the following players to get the best score.",
      "Players: #{Enum.join(Enum.map(state.top_experienced, fn x -> x.name end), ", ")}",
      @splitter,
      "Brute force result:",
      "Team rating diff penalty: #{format(combo_result.rating_diff_penalty)}",
      "Broken avoid penalty: #{combo_result.broken_avoid_penalty}",
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

    # Prefer smaller rating
    rating_importance = -1
    # Prefer team with less players
    size_importance = -100

    # Score
    team_rating * rating_importance + length(team) * size_importance
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
          rating: rating,
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

  @spec has_parties?([BT.expanded_group()]) :: boolean()
  defp has_parties?(expanded_group) do
    Enum.any?(expanded_group, fn x ->
      x.count > 1
    end)
  end

  @spec get_avoids([any()], boolean(), boolean()) :: [String.t()]
  def get_avoids(player_ids, is_ranked?, debug_mode? \\ false) do
    case is_ranked? and !debug_mode? do
      true ->
        avoid_min_hours = 24
        RelationshipLib.get_lobby_avoids(player_ids, avoid_min_hours)

      false ->
        RelationshipLib.get_lobby_avoids(player_ids)
    end
  end

  ## Gets experienced players
  ## Players that are in avoids (in either direction) are at the front, then sort by rating
  def get_experienced_players(players, noobs, avoids) do
    flat_avoids = List.flatten(avoids)

    Enum.filter(players, fn player ->
      !Enum.any?(noobs, fn noob ->
        noob.name == player.name
      end)
    end)
    |> Enum.sort_by(
      fn player ->
        is_in_avoid_list? =
          Enum.any?(flat_avoids, fn id ->
            id == player.id
          end)

        player.rating +
          case is_in_avoid_list? do
            true -> 100
            false -> 0
          end
      end,
      :desc
    )
  end

  # Noobs have high uncertainty
  @spec get_noobs([AP.player()]) :: any()
  def get_noobs(players) do
    Enum.filter(players, fn player ->
      SplitNoobs.is_newish_player?(player.rank, player.uncertainty)
    end)
  end
end
