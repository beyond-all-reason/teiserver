defmodule Teiserver.Battle.Balance.SplitNoobs do
  @moduledoc """
  Seperate players into noobs and experienced players. Noobs are players without a party and either
  high uncertainty or 0 rating. Experienced players are anyone not in the noob category.

  IF THERE ARE PARTIES
  The top 14 experienced players are fed into the brute force algorithm to
  find the best two team combination. To determine the top 14, we prefer players in parties, then prefer higher rating.
  The brute force algo will try and keep parties together and keep both team ratings close.

  Next the teams will draft the remaining experienced players preferring higher rating. Then the teams will draft the noobs
  preferring higher rank and lower uncertainty.

  IF THERE ARE NO PARTIES
  The teams will draft the experienced players first, preferring higher rating. Then they will draft
  the noobs preferring higher rank and lower uncertainty.
  """
  alias Teiserver.Battle.Balance.BalanceTypes, as: BT
  alias Teiserver.Battle.Balance.SplitNoobsTypes, as: SN
  alias Teiserver.Battle.Balance.BruteForce
  import Teiserver.Helper.NumberHelper, only: [format: 1]
  # If player uncertainty is greater than equal to this, that player is considered a noob
  # The lowest uncertainty rank 0 player in integration server at the time of writing this is 6.65
  @high_uncertainty 6.65
  @splitter "------------------------------------------------------"

  @doc """
  Main entry point used by balance_lib
  """
  @spec perform([BT.expanded_group()], non_neg_integer(), list()) :: any()
  def perform(expanded_group, team_count, opts \\ []) do
    initial_state = get_initial_state(expanded_group)

    case should_use_algo(initial_state, team_count) do
      {:ok, :brute_force} ->
        result = get_result(initial_state)
        standardise_result(result, initial_state)

      {:ok, :simple_draft} ->
        result = do_simple_draft(initial_state)
        standardise_result(result, initial_state)

      {:error, message} ->
        # Call another balancer
        result = Teiserver.Battle.Balance.LoserPicks.perform(expanded_group, team_count, opts)

        new_logs =
          ["#{message} Will use loser_picks algorithm instead.", @splitter, result.logs]
          |> List.flatten()

        Map.put(result, :logs, new_logs)
    end
  end

  @spec should_use_algo(SN.state(), integer()) ::
          {:ok, :simple_draft} | {:ok, :brute_force} | {:error, String.t()}
  def should_use_algo(initial_state, team_count) do
    cond do
      team_count != 2 -> {:error, "Team count not equal to 2."}
      has_imbalanced_captains?(initial_state) -> {:ok, :brute_force}
      Enum.empty?(initial_state.parties) -> {:ok, :simple_draft}
      true -> {:ok, :brute_force}
    end
  end

  @spec has_imbalanced_captains?(SN.state()) :: boolean()
  defp has_imbalanced_captains?(state) do
    if Enum.count(state.top_experienced) < 2 do
      false
    else
      # Check diff of best players
      best_player = Enum.at(state.top_experienced, 0)
      second_best_player = Enum.at(state.top_experienced, 1)

      best_player.rating >= second_best_player.rating * 2
    end
  end

  @spec standardise_result(SN.result() | SN.simple_result(), SN.state()) :: any()
  def standardise_result(result, state) do
    first_team = result.first_team
    second_team = result.second_team
    parties = state.parties

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
              log_noob(x)
            end)

          [
            "Solo noobs:",
            noobs_string
          ]

        true ->
          "Solo Noobs: None"
      end

    logs =
      [
        @splitter,
        "Algorithm: split_noobs",
        @splitter,
        "This algorithm will evenly distribute noobs and devalue them. Noobs are non-partied players that have either high uncertainty or 0 rating. Noobs will always be drafted last. For non-noobs, teams will prefer higher rating. For noobs, teams will prefer higher chevrons and lower uncertainty.",
        @splitter,
        "Parties: #{log_parties(parties)}",
        noob_log,
        @splitter,
        result.logs,
        @splitter,
        "Final result:",
        "Team 1: #{log_team(first_team)}",
        "Team 2: #{log_team(second_team)}"
      ]
      |> List.flatten()

    %{
      team_groups: team_groups,
      team_players: team_players,
      logs: logs
    }
  end

  @spec log_parties([[String.t()]]) :: String.t()
  def log_parties(parties) do
    if(Enum.empty?(parties)) do
      "None"
    else
      Enum.map(parties, fn party ->
        "(#{Enum.join(party, ", ")})"
      end)
      |> Enum.join(", ")
    end
  end

  @spec log_team([SN.player()]) :: String.t()
  defp log_team(team) do
    Enum.map(team, fn x ->
      x.name
    end)
    |> Enum.reverse()
    |> Enum.join(", ")
  end

  @spec standardise_team_groups([SN.player()]) :: any()
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

  @spec get_initial_state([BT.expanded_group()]) :: SN.state()
  def get_initial_state(expanded_group) do
    players = flatten_members(expanded_group)
    parties = get_parties(expanded_group)
    noobs = get_noobs(players) |> sort_noobs()

    experienced_players =
      get_experienced_players(players, noobs)
      |> Enum.with_index(fn element, index ->
        element |> Map.put(:index, index + 1)
      end)

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
      parties: parties,
      noobs: noobs,
      top_experienced: top_experienced,
      bottom_experienced: bottom_experienced
    }
  end

  @spec do_simple_draft(SN.state()) :: SN.simple_result()
  def do_simple_draft(state) do
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

  @spec get_result(SN.state()) :: SN.result()
  def get_result(state) do
    # This is the best combo with only the top 14 experienced players
    # This means we brute force at most 14 playesr
    combo_result = BruteForce.get_best_combo(state.top_experienced, state.parties)
    # These are the remaining players who were not involved in the brute force algorithm
    remaining = state.bottom_experienced ++ state.noobs

    logs = [
      "Perform brute force with the following players to get the best score.",
      "Players: #{Enum.join(Enum.map(state.top_experienced, fn x -> log_player(x) end), ", ")}",
      @splitter,
      "Brute force result:",
      "Team rating diff penalty: #{format(combo_result.rating_diff_penalty)}",
      "Broken party penalty: #{combo_result.broken_party_penalty}",
      "Stdev diff penalty: #{format(combo_result.stdev_diff_penalty)}",
      "Captain diff penalty: #{format(combo_result.captain_diff_penalty)}",
      "Score: #{format(combo_result.score)} (lower is better)",
      @splitter,
      "Draft remaining players (ordered from best to worst).",
      "Remaining: #{Enum.join(Enum.map(remaining, fn x -> log_player(x) end), ", ")}"
    ]

    default_acc = combo_result

    # Draft the remaining players
    Enum.reduce(remaining, default_acc, fn noob, acc ->
      picking_team = get_picking_team(acc.first_team, acc.second_team)

      Map.put(acc, picking_team, [noob | acc[picking_team]])
    end)
    |> Map.put(:logs, logs)
  end

  def log_player(%{name: name, rating: rating}) do
    "#{name} (#{format(rating)})"
  end

  def log_noob(%{name: name, rating: rating, uncertainty: uncertainty, rank: rank}) do
    chev = rank || 0 + 1

    "#{name} (#{format(rating)}, chev: #{chev}, σ: #{format(uncertainty)})"
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
          in_party?: count > 1
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

  @spec get_parties([BT.expanded_group()]) :: [String.t()]
  def get_parties(expanded_group) do
    Enum.filter(expanded_group, fn x ->
      x[:count] >= 2
    end)
    |> Enum.map(fn y ->
      y[:names]
    end)
  end

  def get_experienced_players(players, noobs) do
    Enum.filter(players, fn player ->
      !Enum.any?(noobs, fn noob ->
        noob.name == player.name
      end)
    end)
    |> Enum.sort_by(
      fn player ->
        player.rating +
          case player.in_party? do
            true -> 100
            false -> 0
          end
      end,
      :desc
    )
  end

  # Returns noobs that are not part of a party
  # Noobs have high uncertainty or 0 match rating
  @spec get_noobs([SN.player()]) :: any()
  def get_noobs(players) do
    # Noobs are those with 0 rating or high uncertainty

    Enum.filter(players, fn player ->
      cond do
        player.in_party? -> false
        is_newish_player?(player.rank, player.uncertainty) -> true
        player.rating <= 0 -> true
        true -> false
      end
    end)
  end

  def is_newish_player?(rank, uncertainty) do
    uncertainty >= @high_uncertainty && rank <= 2
  end
end
