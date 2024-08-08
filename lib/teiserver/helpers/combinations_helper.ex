defmodule Teiserver.Helper.CombinationsHelper do
  # This module to help get combinations taken from Elixir Forums:
  # https://elixirforum.com/t/create-all-possible-teams-from-a-list-of-players/64892/5?u=joshua.aug
  require Integer

  defp n_comb(0, _list), do: [[]]
  defp n_comb(_, []), do: []

  defp n_comb(n, [h | t]) do
    list = for l <- n_comb(n - 1, t), do: [h | l]
    list ++ n_comb(n, t)
  end

  def n_comb(list) when is_list(list) do
    n = trunc(length(list) / 2)

    for i <- n_comb(n - 1, tl(list)),
        do: [hd(list) | i]
  end

  # Returns a list of possible combinations of a single team using indexes starting at zero
  # but doesn't include duplicates. Assumes we need exactly two teams of equal size.
  # E.g. for a 4 player lobby, Team1: [0,1] is a duplicate of Team1: [2,3]
  # since Team1 and Team2 are just swapped
  def get_combinations(num_players) when is_integer(num_players) do
    last = trunc(num_players) - 1

    0..last |> Enum.to_list() |> n_comb()
  end
end
