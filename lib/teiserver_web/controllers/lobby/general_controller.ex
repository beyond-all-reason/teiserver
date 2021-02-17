defmodule TeiserverWeb.Lobby.GeneralController do
  use CentralWeb, :controller

  plug :add_breadcrumb, name: 'Teiserver', url: '/teiserver'

  def index(conn, _params) do
    render(conn, "index.html")
  end
end