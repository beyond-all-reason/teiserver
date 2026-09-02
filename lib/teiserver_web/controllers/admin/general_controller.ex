defmodule TeiserverWeb.Admin.GeneralController do
  use TeiserverWeb, :controller

  plug(AssignPlug,
    site_menu_active: "admin",
    sub_menu_active: ""
  )

  plug(Bodyguard.Plug.Authorize,
    fallback: TeiserverWeb.Controllers.BodyguardFallback,
    policy: Teiserver.Staff,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}
  )

  @spec metrics(Plug.Conn.t(), map) :: Plug.Conn.t()
  def metrics(conn, _params) do
    conn
    |> redirect(to: "/logging/live/dashboard/metrics?nav=teiserver")
  end
end
