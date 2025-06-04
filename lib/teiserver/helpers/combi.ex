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
end
