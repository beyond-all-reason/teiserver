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
          avoids: [[any()]],
          noobs: [player],
          top_experienced: [player],
          bottom_experienced: [player],
          is_ranked?: boolean(),
          has_parties?: boolean(),
          debug_mode?: boolean()
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
