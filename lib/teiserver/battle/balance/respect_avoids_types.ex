defmodule Teiserver.Battle.Balance.RespectAvoidsTypes do
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
          avoids: [[number()]],
          parties: [[number()]],
          noobs: [player],
          top_experienced: [player],
          bottom_experienced: [player],
          debug_mode?: boolean(),
          lobby_max_avoids: number()
        }

  @type simple_result :: %{
          first_team: [player()],
          second_team: [player()],
          logs: [String.t()]
        }

  @type result :: %{
          broken_avoid_penalty: number(),
          rating_diff_penalty: number(),
          score: number(),
          first_team: [player()],
          second_team: [player()],
          logs: [String.t()]
        }
end
