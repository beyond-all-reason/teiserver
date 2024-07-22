defmodule Teiserver.Battle.Balance.BruteForce do
  @moduledoc """
  Algorithm idea by Suuwassea
  Adjusted by jauggy

  Overview:
  Go through every possible combination and pick the best one. Ideal for keeping parties together.
  The best combination will have the lowest score.
  Score = difference in team rating + broken party penalty
  broken party penalty = num broken parties * broken party multiplier

  Only use for games with two teams and <=16 players
  """
  alias Teiserver.Battle.Balance.BalanceTypes, as: BT
  alias Teiserver.Battle.Balance.BruteForceTypes, as: BF
  import Teiserver.Helper.NumberHelper, only: [format: 1]
  require Integer

  @broken_party_multiplier 3
  @splitter "------------------------------------------------------"

  @doc """
  Main entry point used by balance_lib
  """
  @spec perform([BT.expanded_group()], non_neg_integer(), list()) :: any()
  def perform(expanded_group, team_count, opts \\ []) do
    input_data = %{
      players: flatten_members(expanded_group),
      parties: get_parties(expanded_group)
    }

    case should_use_algo?(input_data, team_count) do
      :ok ->
        potential_teams = potential_teams(length(input_data.players))
        best_combo = get_best_combo(potential_teams, input_data.players, input_data.parties)
        standardise_result(best_combo, input_data.parties)

      {:error, message} ->
        # Call another balancer
        result = Teiserver.Battle.Balance.LoserPicks.perform(expanded_group, team_count, opts)

        new_logs =
          ["#{message} Will use another balance algorithm instead.", @splitter, result.logs]
          |> List.flatten()

        Map.put(result, :logs, new_logs)
    end
  end

  @doc """
  Use this algo if two teams and <=16 players
  """
  @spec should_use_algo?(BF.input_data(), integer()) :: :ok | {:error, String.t()}
  def should_use_algo?(input_data, team_count) do
    num_players = length(input_data[:players])

    cond do
      team_count != 2 -> {:error, "Team count doesn't equal two."}
      num_players > 16 -> {:error, "Number of players greater than 16."}
      Integer.is_odd(num_players) -> {:error, "Odd number of players."}
      true -> :ok
    end
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
        {id, rating, _rank, name, _uncertainty} <-
          Enum.zip([members, ratings, ranks, names, uncertainties]),
        # Create result value
        do: %{
          rating: rating,
          name: name,
          id: id
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

  @spec potential_teams(integer()) :: any()
  def potential_teams(num_players) do
    Teiserver.Helper.CombinationsHelper.get_combinations(num_players)
  end

  def get_best_combo(players, parties) do
    potential_teams = potential_teams(length(players))
    get_best_combo(potential_teams, players, parties)
  end

  @spec get_best_combo([integer()], [BF.player()], [String.t()]) :: BF.combo_result()
  def get_best_combo(combos, players, parties) do
    result =
      Enum.map(combos, fn x ->
        get_players_from_indexes(x, players)
      end)
      |> Enum.map(fn team ->
        result = score_combo(team, players, parties)
        Map.put(result, :first_team, team)
      end)
      |> Enum.min_by(fn z ->
        z.score
      end)

    first_team = result.first_team

    second_team =
      players
      |> Enum.filter(fn x ->
        !Enum.any?(first_team, fn y ->
          y.id == x.id
        end)
      end)

    Map.put(result, :second_team, second_team)
  end

  @spec score_combo([BF.player()], [BF.player()], [String.t()]) :: any()
  def score_combo(first_team, all_players, parties) do
    first_team_rating = get_team_rating(first_team)
    both_team_rating = get_team_rating(all_players)

    rating_diff_penalty = abs(both_team_rating - first_team_rating * 2)
    broken_party_penalty = count_broken_parties(first_team, parties) * @broken_party_multiplier

    score = rating_diff_penalty + broken_party_penalty

    %{
      score: score,
      rating_diff_penalty: rating_diff_penalty,
      broken_party_penalty: broken_party_penalty
    }
  end

  def get_players_from_indexes(player_indexes, players) do
    players = Enum.with_index(players)

    Enum.filter(players, fn {_player, index} ->
      Enum.member?(player_indexes, index)
    end)
    |> Enum.map(fn {player, _index} ->
      player
    end)
  end

  def count_broken_parties(first_team, parties) do
    Enum.count(parties, fn party ->
      is_party_broken?(first_team, party)
    end)
  end

  @spec is_party_broken?([BF.player()], [String.t()]) :: any()
  def is_party_broken?(team, party) do
    count =
      Enum.count(party, fn x ->
        Enum.any?(team, fn y ->
          y.name == x
        end)
      end)

    cond do
      # Nobody from this party is on this team. Therefore unbroken.
      count == 0 -> false
      # Everyone from this party is on this team. Therefore unbroken.
      count == length(party) -> false
      # Otherwise, this party is broken.
      true -> true
    end
  end

  defp get_team_rating(players) do
    Enum.reduce(players, 0, fn x, acc ->
      acc + x.rating
    end)
  end

  @spec standardise_result(BF.combo_result(), [String.t()]) :: any()
  def standardise_result(best_combo, parties) do
    first_team = best_combo.first_team

    second_team = best_combo.second_team

    team_groups = %{
      1 => standardise_team_groups(first_team),
      2 => standardise_team_groups(second_team)
    }

    team_players = %{
      1 => standardise_team_players(first_team),
      2 => standardise_team_players(second_team)
    }

    logs = [
      "Algorithm: brute_force",
      @splitter,
      "Parties: #{log_parties(parties)}",
      "Team rating diff penalty: #{format(best_combo.rating_diff_penalty)}",
      "Broken party penalty: #{best_combo.broken_party_penalty}",
      "Score: #{format(best_combo.score)} (lower is better)",
      "Team 1: #{log_team(first_team)}",
      "Team 2: #{log_team(second_team)}"
    ]

    %{
      team_groups: team_groups,
      team_players: team_players,
      logs: logs
    }
  end

  @spec log_parties([[String.t()]]) :: String.t()
  def log_parties(parties) do
    Enum.map(parties, fn party ->
      "[#{Enum.join(party, ", ")}]"
    end)
    |> Enum.join(", ")
  end

  @spec log_team([BF.player()]) :: String.t()
  defp log_team(team) do
    Enum.map(team, fn x ->
      x.name
    end)
    |> Enum.join(", ")
  end

  @spec standardise_team_groups([BF.player()]) :: any()
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
end
