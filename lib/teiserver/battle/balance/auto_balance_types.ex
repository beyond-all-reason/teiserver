defmodule Teiserver.Battle.Balance.AutoBalanceTypes do
  @moduledoc false

  @type player :: %{
          rank: number(),
          uncertainty: number(),
          rating: number()
        }
end
