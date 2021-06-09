defmodule TeiserverWeb.API.BattleController do
  use CentralWeb, :controller

  # curl -X POST http://localhost:4000/teiserver/api/battle/create -H "Content-Type: application/json" -d '{"guid": "123132341234", "teams": {"1": [1, 2], "2": [3, 4]}, "outcome": "completed", "winner": "1"}'

  def create(conn, _battle = %{"outcome" => "completed"}) do
    conn
    |> render("create.json", %{outcome: :success})
  end

  def create(conn, _battle) do
    conn
    |> render("create.json", %{outcome: :ignored})
  end
end
