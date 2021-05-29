defmodule TeiserverWeb.Admin.GeneralController do
  use CentralWeb, :controller

  plug(AssignPlug,
    sidemenu_active: ["teiserver", "teiserver_admin"]
  )

  plug(Bodyguard.Plug.Authorize,
    policy: Teiserver.Moderator,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}
  )

  plug(:add_breadcrumb, name: 'Teiserver', url: '/teiserver')
  plug(:add_breadcrumb, name: 'Admin', url: '/teiserver/admin')

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, _params) do
    render(conn, "index.html")
  end

  @spec metrics(Plug.Conn.t(), map) :: Plug.Conn.t()
  def metrics(conn, _params) do
    conn
    |> redirect(to: "/logging/live/dashboard/metrics?nav=teiserver")
  end
end
