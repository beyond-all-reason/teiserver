defmodule Teiserver.Battle.Balance.SplitNoobs do
  @moduledoc """
  Seperate players into noobs and experienced players. Noobs are players without a party and either
  high uncertainty or 0 rating.

  IF THERE ARE PARTIES
  If the number of experienced players is <= 14 feed these players into the brute force algorithm to
  find the best two team combination. This brute force algo will try and keep parties together and keep
  both team ratings close.

  Next the teams will draft the remaining noobs. Teams will prefer to pick noobs with higher rank
  and lower uncertainty. We don't trust the rating of noobs so that is ignored.

  If the number of experienced players is > 14 then the brute force algo will take too long so we
  call Teifion's algo instead. We will also call Teifion's algo if team count > 2.

  IF THERE ARE NO PARTIES
  The teams will draft the experienced players first, preferring higher rating. Then they will draft
  the noobs preferring higher rank and lower uncertainty.
  """
  alias Teiserver.Battle.Balance.BalanceTypes, as: BT
  alias Teiserver.Battle.Balance.SplitNoobsTypes, as: SN
  alias Teiserver.Battle.Balance.BruteForce
  import Teiserver.Helper.NumberHelper, only: [format: 1]
  # If player uncertainty is greater than equal to this, that player is considered a noob
  # Going through replays I did find a one chev with 7.17 uncertainty so that's how I came to this number
  @high_uncertainty 7.1
  @splitter "------------------------------------------------------"

  @doc """
  Main entry point used by balance_lib
  """
  @spec perform([BT.expanded_group()], non_neg_integer(), list()) :: any()
  def perform(expanded_group, team_count, opts \\ []) do
    initial_state = get_initial_state(expanded_group)

    case should_use_algo(initial_state, team_count) do
      :ok ->
        result = get_result(initial_state)
        standardise_result(result, initial_state)

      :no_parties ->
        result = do_simple_draft(initial_state)
        standardise_result(result, initial_state)

      {:error, message} ->
        # Call another balancer
        result = Teiserver.Battle.Balance.LoserPicks.perform(expanded_group, team_count, opts)

        new_logs =
          ["#{message} Will use another balance algorithm instead.", @splitter, result.logs]
          |> List.flatten()

        Map.put(result, :logs, new_logs)
    end
  end

  @spec should_use_algo(SN.state(), integer()) :: :ok | {:error, String.t()} | :no_parties
  def should_use_algo(initial_state, team_count) do
    cond do
      team_count > 2 -> {:error, "Team count greater than 2."}
      length(initial_state.parties) == 0 -> :no_parties
      length(initial_state.experienced_players) > 14 -> {:error, "Not enough noobs."}
      true -> :ok
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
              chev = Map.get(x, :rank, 0) + 1
              "#{x.name} (chev: #{chev}, σ: #{format(x.uncertainty)})"
            end)

          [
            "Solo Noobs: (Players not in parties that have either high uncertainty or 0 rating.)",
            noobs_string
          ]

        true ->
          "Solo Noobs: None"
      end

    brute_force_logs =
      case Map.has_key?(result, :score) do
        true ->
          [
            "Team rating diff penalty: #{format(result.rating_diff_penalty)}",
            "Broken party penalty: #{result.broken_party_penalty}",
            "Score: #{format(result.score)} (lower is better)"
          ]

        false ->
          "Teams constructed by simple draft."
      end

    logs =
      [
        @splitter,
        "Algorithm: split_noobs",
        @splitter,
        "Parties: #{log_parties(parties)}",
        noob_log,
        @splitter,
        "Team 1: #{log_team(first_team)}",
        "Team 2: #{log_team(second_team)}",
        brute_force_logs
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
    if(length(parties) == 0) do
      "None"
    else
      Enum.map(parties, fn party ->
        "[#{Enum.join(party, ", ")}]"
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
    noobs = get_noobs(players, parties) |> sort_noobs()
    experienced_players = get_experienced_players(players, noobs)

    %{
      players: players,
      parties: parties,
      noobs: noobs,
      experienced_players: experienced_players
    }
  end

  @spec do_simple_draft(SN.state()) :: SN.simple_result()
  def do_simple_draft(state) do
    # This is the best combo with only non noobs
    default_acc = %{
      first_team: [],
      second_team: []
    }

    experienced_players =
      state.experienced_players
      |> Enum.sort_by(
        fn x ->
          x.rating
        end,
        :desc
      )

    noobs = state.noobs
    sorted_players = experienced_players ++ noobs

    Enum.reduce(sorted_players, default_acc, fn x, acc ->
      picking_team = get_picking_team(acc.first_team, acc.second_team)

      if(picking_team == 1) do
        Map.put(acc, :first_team, [x | acc.first_team])
      else
        Map.put(acc, :second_team, [x | acc.second_team])
      end
    end)
  end

  @spec get_result(SN.state()) :: SN.result()
  def get_result(state) do
    # This is the best combo with only non noobs
    default_acc = BruteForce.get_best_combo(state.experienced_players, state.parties)

    noobs = state.noobs

    Enum.reduce(noobs, default_acc, fn noob, acc ->
      picking_team = get_picking_team(acc.first_team, acc.second_team)

      if(picking_team == 1) do
        Map.put(acc, :first_team, [noob | acc.first_team])
      else
        Map.put(acc, :second_team, [noob | acc.second_team])
      end
    end)
  end

  def get_picking_team(first_team, second_team) do
    first_team_pick_priority = get_pick_priority(first_team)
    second_team_pick_priority = get_pick_priority(second_team)

    if(first_team_pick_priority > second_team_pick_priority) do
      1
    else
      2
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
          uncertainties: uncertainties
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
          rank: rank
        }
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
  end

  # Returns noobs that are not part of a party
  # Noobs have high uncertainty or 0 match rating
  @spec get_noobs([SN.player()], [[String.t()]]) :: any()
  def get_noobs(players, parties) do
    # Noobs are those with 0 rating or high uncertainty
    noobs =
      Enum.filter(players, fn player ->
        cond do
          player.uncertainty >= @high_uncertainty -> true
          player.rating <= 0 -> true
          true -> false
        end
      end)

    flat_parties = parties |> List.flatten()
    # Noobs without parties
    noobs
    |> Enum.filter(fn noob ->
      !Enum.member?(flat_parties, noob.name)
    end)
  end
end
