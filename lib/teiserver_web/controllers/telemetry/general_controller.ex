defmodule TeiserverWeb.Telemetry.GeneralController do
  use TeiserverWeb, :controller

  plug(AssignPlug,
    site_menu_active: "telemetry",
    sub_menu_active: ""
  )

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Auth.Telemetry,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}

  plug(:add_breadcrumb, name: "Telemetry", url: "/telemetry")

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, _params) do
    conn
    |> render("index.html")
  end
end
