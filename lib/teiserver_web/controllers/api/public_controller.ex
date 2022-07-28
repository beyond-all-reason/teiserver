defmodule TeiserverWeb.API.PublicController do
  use CentralWeb, :controller
  # alias Teiserver.Battle

  @spec leaderboard(Plug.Conn.t(), map) :: Plug.Conn.t()
  def leaderboard(conn, %{"type" => _rating_type}) do
    ratings = []

    conn
      |> put_status(201)
      |> render("leaderboard.json", %{ratings: ratings})
  end
end
