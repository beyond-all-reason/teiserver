defprotocol GroupLength do
  @doc "What is the length of the group?"
  @spec length(term()) :: non_neg_integer()
  def length(group)
end

defimpl GroupLength, for: Integer do
  def length(_), do: 1
end

defimpl GroupLength, for: List do
  def length(l), do: Kernel.length(l)
end

defmodule Teiserver.Helpers.Combi do
  @moduledoc """
  Combinatorial helpers
  """

  require Integer

  @doc """
  Returns a stream of combinations: pick k items in the given list. Each item
  in the list can have a different length, checked with the GroupLength protocol
  """
  @spec combinations([term()], non_neg_integer()) :: Enumerable.t([term()])
  def combinations(list, k) do
    cond do
      k < 0 ->
        Stream.from_index() |> Stream.take(0)

      k == 0 ->
        [[]]

      true ->
        case list do
          [] ->
            Stream.from_index() |> Stream.take(0)

          [h | t] ->
            st1 =
              Stream.map(lazy(__MODULE__, :combinations, [t, k - GroupLength.length(h)]), fn x ->
                [h] ++ x
              end)

            st2 = lazy(__MODULE__, :combinations, [t, k])
            Stream.concat(st1, st2)
        end
    end
  end

  defp lazy(m, f, a),
    do:
      Stream.resource(
        fn -> {{m, f, a}, true} end,
        fn
          {{m, f, a}, true} -> {apply(m, f, a), false}
          false -> {:halt, nil}
        end,
        fn _ -> nil end
      )

  # Returns a list of possible combinations of a single team using indexes starting at zero
  # The other team can then be constructed from the leftover
  # This assumes only 2 teams.
  # When the number of player is even, cuts the combinations by 2 since
  # they are symmetrical: picking [0,1] for the first team, and thus, forcing
  # [2,3] in team 2, is the same as picking [2,3] for the first team.
  @spec get_single_teams(integer()) :: [integer()]
  def get_single_teams(num_players) do
    team_size = trunc(num_players / 2)
    stream = Enum.to_list(0..(num_players - 1)) |> combinations(team_size)

    if Integer.is_even(num_players) do
      n = fact(num_players) / (fact(team_size) * fact(num_players - team_size))
      Stream.take(stream, trunc(n / 2)) |> Enum.to_list()
    else
      # there is no mirroring when odd number of player, so just get everything
      Enum.to_list(stream)
    end
  end

  # fact(n) == n! == n * (n-1) * (n-2) * ... * 2
  def fact(n, acc \\ 1)
  def fact(n, acc) when n <= 1, do: acc
  def fact(n, acc), do: fact(n - 1, acc * n)
end
