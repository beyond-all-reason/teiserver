defmodule TeiserverWeb.Admin.GeneralController do
  use CentralWeb, :controller

  plug :add_breadcrumb, name: 'Teiserver', url: '/teiserver'
  plug :add_breadcrumb, name: 'Admin', url: '/teiserver/admin'

  plug AssignPlug,
    sidemenu_active: "teiserver"

  def index(conn, _params) do
    render(conn, "index.html")
  end
end