defmodule Teiserver.Battle.Balance.SplitOneChevsTypes do
  @moduledoc false

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
