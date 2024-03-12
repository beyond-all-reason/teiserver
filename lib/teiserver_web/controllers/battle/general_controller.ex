defmodule BarserverWeb.Battle.GeneralController do
  use BarserverWeb, :controller

  plug(:add_breadcrumb, name: 'Battle', url: '/battle')

  plug(AssignPlug,
    site_menu_active: "teiserver_match",
    sub_menu_active: ""
  )

  plug(Barserver.ServerUserPlug)

  @spec index(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def index(conn, _params) do
    render(conn, "index.html")
  end
end
