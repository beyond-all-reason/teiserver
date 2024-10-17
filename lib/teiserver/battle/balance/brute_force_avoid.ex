defmodule Teiserver.Battle.Balance.BruteForceAvoid do
  @moduledoc """
  Overview:
  Go through every possible combination and pick the best one. Each combination is given a score
  Score = team rating penalty + broken avoid penalty + broken party penalty + broken max team rating diff penalty
  team rating penalty = difference in team ratings
  broken avoid penalty = broken avoid count * avoid importance
  broken party penalty = broken party count * party importance
  broken max team rating diff penalty = max team diff importance (if the team rating diff > @max_team_diff)

  Only use for games with two teams.

  This is not a balance algorithm that is callable players. It's a lib that can be used by another balance algorithm.
  """
  alias Teiserver.Config
  alias Teiserver.Battle.Balance.BruteForceAvoidTypes, as: BF
  require Integer

  # Parties will be split if team diff is too large. It either uses absolute value or percentage
  # See get_max_team_diff function below for full details
  @max_team_diff_abs 10
  @max_team_diff_importance 10000
  @party_importance 1000
  @avoid_importance 10

  def get_best_combo(players, avoids, parties) do
    potential_teams = potential_teams(length(players))
    get_best_combo(potential_teams, players, avoids, parties)
  end

  @spec get_best_combo([integer()], [BF.player()], [[number()]], [[number()]]) ::
          BF.combo_result()
  def get_best_combo(combos, players, avoids, parties) do
    players_with_index = Enum.with_index(players)

    # Go through every possibility and get the combination with the lowest score
    result =
      Enum.map(combos, fn x ->
        team = get_players_from_indexes(x, players_with_index)
        result = score_combo(team, players, avoids, parties)
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

  @spec potential_teams(integer()) :: any()
  def potential_teams(num_players) do
    Teiserver.Helper.CombinationsHelper.get_combinations(num_players)
  end

  # Parties/avoids will be ignored if the team rating diff is too large
  # This function returns the allowed team difference
  # By default, it is either 10 rating points or 5% of a single team rating - whichever is larger
  defp get_max_team_diff(total_lobby_rating, num_teams) do
    # This value is 10% in dev but 5% in production. Can be adjusted by Admin
    percentage_of_team = Config.get_site_config_cache("teiserver.Max deviation") / 100
    max(total_lobby_rating / num_teams * percentage_of_team, @max_team_diff_abs)
  end

  @spec score_combo([BF.player()], [BF.player()], [[number()]], [[number()]]) :: any()
  def score_combo(first_team, all_players, avoids, parties) do
    first_team_rating = get_team_rating(first_team)
    both_team_rating = get_team_rating(all_players)
    rating_diff_penalty = abs(both_team_rating - first_team_rating * 2)
    num_teams = 2

    max_team_diff_penalty =
      cond do
        rating_diff_penalty > get_max_team_diff(both_team_rating, num_teams) ->
          @max_team_diff_importance

        true ->
          0
      end

    # If max_team_diff_penalty is non zero don't even bother calculating avoid and party penalty
    # since it's likely we'll discard this combo
    {broken_avoid_penalty, broken_party_penalty} =
      case max_team_diff_penalty do
        0 ->
          {count_broken_avoids(first_team, avoids) * @avoid_importance,
           count_broken_parties(first_team, parties) * @party_importance}

        _ ->
          {0, 0}
      end

    score =
      rating_diff_penalty + broken_avoid_penalty + broken_party_penalty + max_team_diff_penalty

    %{
      score: score,
      rating_diff_penalty: rating_diff_penalty,
      broken_avoid_penalty: broken_avoid_penalty,
      broken_party_penalty: broken_party_penalty
    }
  end

  def get_players_from_indexes(player_indexes, players_with_index) do
    players_with_index
    |> Enum.filter(fn {_player, index} -> index in player_indexes end)
    |> Enum.map(fn {player, _index} -> player end)
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
          y.id == x
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
