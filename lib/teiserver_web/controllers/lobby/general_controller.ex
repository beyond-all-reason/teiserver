defmodule TeiserverWeb.Lobby.GeneralController do
  use CentralWeb, :controller

  plug(:add_breadcrumb, name: 'Teiserver', url: '/teiserver')

  plug(AssignPlug,
    sidemenu_active: "teiserver"
  )

  plug(Teiserver.ServerUserPlug)

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def accimp(conn, _params) do
    if allow?(conn, "dev") do
      Teiserver.AccountImport.run()

      render(conn, "index.html")
    end
  end
end
