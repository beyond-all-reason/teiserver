defmodule TeiserverWeb.Admin.ToolController do
  use TeiserverWeb, :controller

  plug(AssignPlug,
    site_menu_active: "admin",
    sub_menu_active: "tool"
  )

  plug Bodyguard.Plug.Authorize,
    fallback: TeiserverWeb.Controllers.BodyguardFallback,
    policy: Teiserver.Account.Admin,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}

  plug(:add_breadcrumb, name: "Admin", url: "/teiserver/admin")
  plug(:add_breadcrumb, name: "Tools", url: "/teiserver/admin/tools")

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    conn
    |> render("index.html")
  end

  # List of font awesome icons
  @spec falist(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def falist(conn, _params) do
    conn
    |> render("falist.html")
  end
end
