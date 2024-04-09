defmodule Teiserver.Battle.Balance.SplitOneChevsTypes do
  @moduledoc false
  # alias Teiserver.Battle.Balance.BalanceTypes, as: BT

  @type member :: %{
          rating: float(),
          rank: non_neg_integer(),
          member_id: any()
        }
  @type team :: %{
    members: [member],
    team_id: integer()
  }
end
