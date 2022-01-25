defmodule TeiserverWeb.Battle.GeneralController do
  use CentralWeb, :controller

  plug(:add_breadcrumb, name: 'Teiserver', url: '/teiserver')
  plug(:add_breadcrumb, name: 'Battle', url: '/teiserver/battle')

  plug(AssignPlug,
    site_menu_active: "teiserver_match",
    sub_menu_active: "",
  )

  plug(Teiserver.ServerUserPlug)

  @spec index(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def index(conn, _params) do
    render(conn, "index.html")
  end
end
