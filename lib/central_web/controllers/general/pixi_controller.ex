defmodule CentralWeb.General.PixiController do
  use CentralWeb, :controller

  def index(conn, _params) do
    conn
    |> render("index.html")
  end
end
