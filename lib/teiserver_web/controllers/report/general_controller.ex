defmodule BarserverWeb.Report.GeneralController do
  use BarserverWeb, :controller

  plug(AssignPlug,
    site_menu_active: "teiserver_report",
    sub_menu_active: ""
  )

  plug Bodyguard.Plug.Authorize,
    policy: Barserver.Staff,
    action: {Phoenix.Controller, :action_name},
    user: {Barserver.Account.AuthLib, :current_user}

  plug(:add_breadcrumb, name: 'Reports', url: '/teiserver/reports')

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, _params) do
    conn
    |> render("index.html")
  end
end
