defmodule TeiserverWeb.Admin.GeneralController do
  use TeiserverWeb, :controller

  plug(AssignPlug,
    site_menu_active: "admin",
    sub_menu_active: ""
  )

  plug(Bodyguard.Plug.Authorize,
    policy: Teiserver.Staff,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}
  )

  plug(:add_breadcrumb, name: "Admin", url: "/teiserver/admin")

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
