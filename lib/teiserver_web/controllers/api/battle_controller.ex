defmodule TeiserverWeb.API.BattleController do
  use CentralWeb, :controller
  alias Teiserver.Battle

  # curl -X POST http://localhost:4000/teiserver/api/battle/create -H "Content-Type: application/json" -d '{"guid": "123132341234", "teams": {"1": [1, 2], "2": [3, 4]}, "outcome": "completed", "winner": "1"}' -v

  # curl -X POST http://localhost:4000/teiserver/api/battle/create -H "Content-Type: application/json" -d '{"guid": "123132341234", "teams": {"1": [1, 2], "2": [3, 4]}, "outcome": "srtdrstd", "winner": "1"}' -v

  # curl -X POST http://localhost:4000/teiserver/api/battle/create -H "Content-Type: application/json" -d '{rstdrstdrstd, rstdrstdr std}' -v

  def create(conn, battle = %{"outcome" => "completed"}) do
    guid = UUID.uuid4()

    Battle.create_battle_log(%{
      guid: guid,
      data: battle,
      team_count: 1,
      players: [],
      spectators: [],
      started: Timex.now(),
      finished: Timex.now() |> Timex.shift(minutes: 20)
    })

    conn
    |> put_status(201)
    |> render("create.json", %{outcome: :success, guid: guid})
  end

  def create(conn, _battle) do
    conn
    |> put_status(400)
    |> render("create.json", %{outcome: :ignored, reason: "Not a completed battle"})
  end
end
