defmodule Teiserver.Battle.Balance.DefaultBalanceTypes do
  @moduledoc false

  @type player :: %{
          rank: number(),
          uncertainty: number()
        }
end
