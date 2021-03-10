defmodule TeiserverWeb.Account.GeneralController do
  use CentralWeb, :controller

  plug(:add_breadcrumb, name: 'Teiserver', url: '/teiserver')
  plug(:add_breadcrumb, name: 'Account', url: '/teiserver/account')

  plug(AssignPlug,
    sidemenu_active: "teiserver"
  )

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, _params) do
    render(conn, "index.html")
  end
end
