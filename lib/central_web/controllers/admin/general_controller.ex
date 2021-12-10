defmodule CentralWeb.Admin.GeneralController do
  use CentralWeb, :controller

  plug :add_breadcrumb, name: 'Admin', url: '/admin'

  plug Bodyguard.Plug.Authorize,
    policy: Central.Admin,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug(AssignPlug,
    sidemenu_active: ["admin"]
  )

  @spec index(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def index(conn, _params) do
    conn
    |> render("index.html")
  end
end
