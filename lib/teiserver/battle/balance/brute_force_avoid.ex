defmodule Teiserver.Battle.Balance.BruteForceAvoid do
  @moduledoc """
  Overview:
  Go through every possible combination and pick the best one. Each combination is given a score
  Score = team rating penalty + broken avoid penalty
  team rating penalty = difference in team ratings
  broken avoid penalty = player's avoid not respected * avoid importance

  Only use for games with two teams.

  This is not a balance algorithm that is callable players. It's a lib that can be used by another balance algorithm.
  """
  alias Teiserver.Battle.Balance.BruteForceAvoidTypes, as: BF
  require Integer

  @avoid_importance 10

  def get_best_combo(players, avoids) do
    potential_teams = potential_teams(length(players))
    get_best_combo(potential_teams, players, avoids)
  end

  @spec potential_teams(integer()) :: any()
  def potential_teams(num_players) do
    Teiserver.Helper.CombinationsHelper.get_combinations(num_players)
  end

  @spec get_best_combo([integer()], [BF.player()], [[any()]]) :: BF.combo_result()
  def get_best_combo(combos, players, avoids) do
    players_with_index = Enum.with_index(players)

    # Go through every possibility and get the combination with the lowest score
    result =
      Enum.map(combos, fn x ->
        get_players_from_indexes(x, players_with_index)
      end)
      |> Enum.map(fn team ->
        result = score_combo(team, players, avoids)
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

  @spec score_combo([BF.player()], [BF.player()], [[any()]]) :: any()
  def score_combo(first_team, all_players, avoids) do
    first_team_rating = get_team_rating(first_team)
    both_team_rating = get_team_rating(all_players)

    rating_diff_penalty = abs(both_team_rating - first_team_rating * 2)
    broken_avoid_penalty = count_broken_avoids(first_team, avoids) * @avoid_importance

    score = rating_diff_penalty + broken_avoid_penalty

    %{
      score: score,
      rating_diff_penalty: rating_diff_penalty,
      broken_avoid_penalty: broken_avoid_penalty
    }
  end

  def get_players_from_indexes(player_indexes, players_with_index) do
    Enum.filter(players_with_index, fn {_player, index} ->
      Enum.member?(player_indexes, index)
    end)
    |> Enum.map(fn {player, _index} ->
      player
    end)
  end

  def count_broken_avoids(first_team, avoids) do
    Enum.count(avoids, fn avoid ->
      is_avoid_broken?(first_team, avoid)
    end)
  end

  @spec is_avoid_broken?([BF.player()], [[any()]]) :: any()
  def is_avoid_broken?(team, avoids) do
    count =
      Enum.count(avoids, fn x ->
        Enum.any?(team, fn y ->
          y.id == x
        end)
      end)

    cond do
      # One person from avoid on this team. The other must be on other team. Avoid is respected.
      count == 1 -> false
      # Otherwise avoid is broken
      true -> true
    end
  end

  defp get_team_rating(players) do
    Enum.reduce(players, 0, fn x, acc ->
      acc + x.rating
    end)
  end
end
