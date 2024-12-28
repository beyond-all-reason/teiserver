defmodule Teiserver.Battle.Balance.WinPredict do
  @moduledoc """
  Balance teams using win prediction algorithm
  """

  alias Teiserver.Battle.Balance.BalanceTypes, as: BT
  alias Openskill

  @max_iterations 100
  @tolerance 0.01
  @splitter "------------------------------------------------------"

  @spec perform([BT.expanded_group()], non_neg_integer(), list()) :: map()
  def perform(expanded_group, team_count, _opts \\ []) do
    input_data = %{
      players: flatten_members(expanded_group),
      parties: get_parties(expanded_group)
    }

    case should_use_algo?(input_data, team_count) do
      :ok ->
        initial_teams = create_initial_teams(input_data.players, team_count)
        balanced_teams = balance_teams(initial_teams)
        standardise_result(balanced_teams, input_data.parties)

      {:error, message} ->
        result = Teiserver.Battle.Balance.LoserPicks.perform(expanded_group, team_count)
        Map.put(result, :logs, ["#{message} Using LoserPicks instead.", @splitter | result.logs])
    end
  end

  defp flatten_members(expanded_group) do
    for %{members: members, ratings: ratings, uncertainties: uncertainties} <- expanded_group,
        {rating, uncertainty} <- Enum.zip(ratings, uncertainties),
        do: {rating, uncertainty}
  end

  defp get_parties(expanded_group) do
    Enum.filter(expanded_group, fn x -> x[:count] >= 2 end)
    |> Enum.map(& &1[:names])
  end

  defp should_use_algo?(input_data, team_count) do
    cond do
      team_count < 2 -> {:error, "Requires at least 2 teams"}
      length(input_data.players) < team_count -> {:error, "Not enough players"}
      true -> :ok
    end
  end

  defp create_initial_teams(players, team_count) do
    players
    |> Enum.shuffle()
    |> Enum.chunk_every(ceil(length(players) / team_count))
  end

  defp balance_teams(teams) do
    Enum.reduce_while(1..@max_iterations, teams, fn _iteration, current_teams ->
      predictions = Openskill.predict_win(current_teams)
      variance = prediction_variance(predictions)

      if variance < @tolerance do
        {:halt, current_teams}
      else
        case try_improve_balance(current_teams) do
          {:improved, new_teams} -> {:cont, new_teams}
          :no_improvement -> {:halt, current_teams}
        end
      end
    end)
  end

  defp prediction_variance(predictions) do
    mean = Enum.sum(predictions) / length(predictions)
    squared_diffs = Enum.map(predictions, fn pred ->
      diff = pred - mean
      diff * diff
    end)
    Enum.sum(squared_diffs) / length(predictions)
  end

  defp try_improve_balance(teams) do
    predictions = Openskill.predict_win(teams)
    {high_idx, low_idx} = find_extreme_teams(predictions)

    case find_best_swap(teams, high_idx, low_idx) do
      nil -> :no_improvement
      new_teams -> {:improved, new_teams}
    end
  end

  defp find_extreme_teams(predictions) do
    predictions_with_index = Enum.with_index(predictions)
    {_, high_idx} = Enum.max_by(predictions_with_index, fn {v, _} -> v end)
    {_, low_idx} = Enum.min_by(predictions_with_index, fn {v, _} -> v end)
    {high_idx, low_idx}
end

defp find_best_swap(teams, team1_idx, team2_idx) when is_integer(team1_idx) and is_integer(team2_idx) do
    team1 = Enum.at(teams, team1_idx) || []
    team2 = Enum.at(teams, team2_idx) || []

    possible_swaps = for p1 <- team1, p2 <- team2, do: {p1, p2}

    Enum.find_value(possible_swaps, fn {p1, p2} ->
        new_teams = swap_players(teams, team1_idx, team2_idx, p1, p2)
        if improved?(new_teams, teams), do: new_teams
    end)
end

  defp swap_players(teams, idx1, idx2, player1, player2) do
    teams
    |> List.update_at(idx1, fn team ->
      List.delete(team, player1) ++ [player2]
    end)
    |> List.update_at(idx2, fn team ->
      List.delete(team, player2) ++ [player1]
    end)
  end

  defp improved?(new_teams, old_teams) do
    new_variance = new_teams |> Openskill.predict_win() |> prediction_variance()
    old_variance = old_teams |> Openskill.predict_win() |> prediction_variance()
    new_variance < old_variance
  end

  defp standardise_result(teams, parties) do
    %{
      team_players: standardise_team_players(teams),
      team_groups: standardise_team_groups(teams),
      logs: generate_logs(teams, parties)
    }
  end

  defp standardise_team_players(teams) do
    teams
    |> Enum.with_index()
    |> Enum.flat_map(fn {team, idx} ->
      Enum.map(team, fn {rating, _} ->
        %{team_id: idx + 1, player_id: rating}
      end)
    end)
  end

  defp standardise_team_groups(teams) do
    teams
    |> Enum.with_index()
    |> Enum.map(fn {team, idx} ->
      %{
        team_id: idx + 1,
        mean_rating: Enum.sum(Enum.map(team, fn {r, _} -> r end)) / length(team)
      }
    end)
  end

  defp generate_logs(teams, _parties) do
    [
      "Win Prediction Balance Algorithm",
      "Final team predictions: #{inspect(Openskill.predict_win(teams))}",
      @splitter
    ]
  end
end
