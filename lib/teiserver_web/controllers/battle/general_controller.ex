defmodule TeiserverWeb.Battle.GeneralController do
  use CentralWeb, :controller

  plug :add_breadcrumb, name: 'Teiserver', url: '/teiserver'
  plug :add_breadcrumb, name: 'Battle', url: '/teiserver/battle'

  def index(conn, _params) do
    render(conn, "index.html")
  end
end