defmodule TeiserverWeb.Admin.GeneralController do
  use CentralWeb, :controller

  plug(AssignPlug,
    sidemenu_active: "teiserver"
  )

  plug(Bodyguard.Plug.Authorize,
    policy: Teiserver.Account.Auth,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}
  )

  plug(:add_breadcrumb, name: 'Teiserver', url: '/teiserver')
  plug(:add_breadcrumb, name: 'Admin', url: '/teiserver/admin')

  def index(conn, _params) do
    conn
    |> redirect(to: Routes.ts_lobby_general_path(conn, :index))
  end
end
