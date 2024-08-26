defmodule Teiserver.Battle.Balance.DefaultBalance do
  @moduledoc """
  This will call other balancers depending on circumstances
  """
  alias Teiserver.Battle.Balance.SplitNoobs
  alias Teiserver.Battle.Balance.LoserPicks
  alias Teiserver.Battle.Balance.SplitNoobsTypes, as: SN
  alias Teiserver.Battle.Balance.BalanceTypes, as: BT

  @doc """
  Main entry point used by balance_lib
  """
  @spec perform([BT.expanded_group()], non_neg_integer(), list()) :: any()
  def perform(expanded_group, team_count, opts \\ []) do
    case should_use_algo(expanded_group, team_count) do
      "split_noobs" ->
        SplitNoobs.perform(expanded_group, team_count, opts)

      _ ->
        LoserPicks.perform(expanded_group, team_count, opts)
    end
  end

  @spec should_use_algo([BT.expanded_group()], integer()) ::
          String.t()
  def should_use_algo(expanded_group, team_count) do
    cond do
      team_count != 2 ->
        "loser_picks"

      true ->
        players = flatten_members(expanded_group)
        has_noobs? = has_noobs?(players)

        cond do
          has_noobs? -> "split_noobs"
          true -> "loser_picks"
        end
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

  @spec has_noobs?([SN.player()]) :: any()
  def has_noobs?(players) do
    Enum.any?(players, fn x ->
      SplitNoobs.is_newish_player?(x.rank, x.uncertainty)
    end)
  end
end
