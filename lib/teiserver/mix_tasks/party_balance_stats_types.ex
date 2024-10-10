defmodule Mix.Tasks.Teiserver.PartyBalanceStatsTypes do
  @moduledoc false
  # alias Teiserver.Battle.Balance.BalanceTypes, as: BT

  @type balance_result :: %{
          match_id: number(),
          parties: [[number()]],
          team_players: %{1 => [number()], 2 => [number()]}
        }
end
