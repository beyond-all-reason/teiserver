defmodule Teiserver.Battle.Balance.BruteForceTypes do
  @moduledoc false

  @type player :: %{
          rating: float(),
          id: any(),
          name: String.t()
        }
  @type team :: %{
          players: [player],
          id: integer()
        }
  @type input_data :: %{
          players: [player],
          parties: [String.t()]
        }

  @type combo_result :: %{
          broken_party_penalty: number(),
          rating_diff_penalty: number(),
          score: number(),
          team: [player()]
        }
end
