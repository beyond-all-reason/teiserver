defmodule TeiserverWeb.Report.GeneralController do
  use TeiserverWeb, :controller

  plug(AssignPlug,
    site_menu_active: "teiserver_report",
    sub_menu_active: ""
  )

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Staff,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}

  plug(:add_breadcrumb, name: "Reports", url: "/teiserver/reports")

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, _params) do
    conn
    |> render("index.html")
  end
end
