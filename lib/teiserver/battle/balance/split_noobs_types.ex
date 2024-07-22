defmodule Teiserver.Battle.Balance.SplitNoobsTypes do
  @moduledoc false

  @type player :: %{
          rating: float(),
          id: any(),
          name: String.t(),
          uncertainty: float()
        }
  @type team :: %{
          players: [player],
          id: integer()
        }
  @type state :: %{
          players: [player],
          parties: [String.t()],
          noobs: [player],
          experienced_players: [player]
        }

  @type result :: %{
          broken_party_penalty: number(),
          rating_diff_penalty: number(),
          score: number(),
          first_team: [player()],
          second_team: [player()]
        }
end
