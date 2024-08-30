defmodule TeiserverWeb.Battle.GeneralController do
  use TeiserverWeb, :controller

  plug(:add_breadcrumb, name: "Battle", url: "/battle")

  plug(AssignPlug,
    site_menu_active: "teiserver_match",
    sub_menu_active: ""
  )

  plug(Teiserver.ServerUserPlug)

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    render(conn, "index.html")
  end
end
