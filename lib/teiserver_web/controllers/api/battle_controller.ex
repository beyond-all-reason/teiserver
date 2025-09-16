defmodule TeiserverWeb.API.BattleController do
  use TeiserverWeb, :controller
  # alias Teiserver.Battle

  plug(Bodyguard.Plug.Authorize,
    policy: Teiserver.Battle.ApiAuth,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}
  )

  def create(conn, %{"outcome" => "completed"}) do
    conn
    |> put_status(201)
    |> render("create.json", %{outcome: :success, id: 1})
  end

  def create(conn, _battle) do
    conn
    |> put_status(400)
    |> render("create.json", %{outcome: :ignored, reason: "Not a completed battle"})
  end
end
