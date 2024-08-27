defmodule Teiserver.Battle.Balance.DefaultBalance do
  @moduledoc """
  This will call other balancers depending on circumstances
  """
  alias Teiserver.Battle.Balance.SplitNoobs
  alias Teiserver.Battle.Balance.LoserPicks
  alias Teiserver.Battle.Balance.BalanceTypes, as: BT
  alias Teiserver.Battle.Balance.DefaultBalanceTypes, as: DB

  @doc """
  Main entry point used by balance_lib
  """
  @spec perform([BT.expanded_group()], non_neg_integer(), list()) :: any()
  def perform(expanded_group, team_count, opts \\ []) do
    get_balance_algorithm(expanded_group, team_count).perform(expanded_group, team_count, opts)
  end

  @spec get_balance_algorithm([BT.expanded_group()], integer()) ::
          any()
  def get_balance_algorithm(expanded_group, team_count) do
    cond do
      team_count != 2 ->
        LoserPicks

      true ->
        players = flatten_members(expanded_group)
        has_noobs? = has_noobs?(players)

        cond do
          has_noobs? -> SplitNoobs
          true -> LoserPicks
        end
    end
  end

  @doc """
  Converts the input to a simple list of players
  """
  @spec flatten_members([BT.expanded_group()]) :: [DB.player()]
  def flatten_members(expanded_group) do
    # We only care about ranks and uncertainties for now
    # However, in the future we may use other data to decide what balance algorithm to use,
    # e.g. whether there are parties or not, whether it's a high rating lobby, etc.
    for %{
          ranks: ranks,
          uncertainties: uncertainties
        } <- expanded_group,
        # Zipping will create binary tuples from 2 lists
        {rank, uncertainty} <-
          Enum.zip([ranks, uncertainties]),
        do: %{
          uncertainty: uncertainty,
          rank: rank
        }
  end

  @spec has_noobs?([DB.player()]) :: any()
  def has_noobs?(players) do
    Enum.any?(players, fn x ->
      SplitNoobs.is_newish_player?(x.rank, x.uncertainty)
    end)
  end
end
