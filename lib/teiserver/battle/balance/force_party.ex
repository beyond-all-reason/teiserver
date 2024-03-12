defmodule Barserver.Battle.Balance.ForceParty do
  @moduledoc """
  Currently just points to Loser picks
  """

  # Alias the types
  # alias Barserver.Account
  # alias Barserver.Battle.BalanceLib
  alias Barserver.Battle.Balance.BalanceTypes, as: BT
  # import Barserver.Helper.NumberHelper, only: [round: 2]

  # @type algorithm_state :: %{
  #   teams: map,
  #   logs: list,
  #   solo_players: list,
  #   opts: list
  # }

  @doc """

  """
  @spec perform([BT.expanded_group_or_pair()], non_neg_integer(), list()) :: BT.algorithm_result()
  def perform(raw_groups, team_count, opts) do
    Barserver.Battle.Balance.LoserPicks.perform(raw_groups, team_count, opts)
  end
end
