defmodule Teiserver.Battle.Balance.SplitNoobsTypes do
  @moduledoc false

  @type player :: %{
          rating: float(),
          id: any(),
          name: String.t(),
          uncertainty: float(),
          in_party?: boolean()
        }
  @type team :: %{
          players: [player],
          id: integer()
        }
  @type state :: %{
          players: [player],
          parties: [String.t()],
          noobs: [player],
          top_experienced: [player],
          bottom_experienced: [player]
        }

  @type simple_result :: %{
          first_team: [player()],
          second_team: [player()],
          logs: [String.t()]
        }

  @type result :: %{
          broken_party_penalty: number(),
          rating_diff_penalty: number(),
          score: number(),
          first_team: [player()],
          second_team: [player()],
          logs: [String.t()]
        }
end
