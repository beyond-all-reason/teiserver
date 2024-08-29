defmodule TeiserverWeb.Admin.ToolController do
  use TeiserverWeb, :controller

  plug(AssignPlug,
    site_menu_active: "admin",
    sub_menu_active: "tool"
  )

  plug Bodyguard.Plug.Authorize,
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

  @spec test_page(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def test_page(conn, params) do
    layout =
      case params["layout"] do
        "unauth" -> "unauth.html"
        "empty" -> "empty.html"
        "nomenu" -> "nomenu.html"
        "nomenu_live" -> "nomenu_live.html"
        "admin_live" -> "admin_live.html"
        "admin" -> "admin.html"
        _ -> "standard.html"
      end

    conn =
      if params["flash"] do
        conn
        |> put_flash(:success, "Example flash message success")
        |> put_flash(:info, "Example flash message info")
        |> put_flash(:warning, "Example flash message warning")
        |> put_flash(:danger, "Example flash message danger")
      else
        conn
      end

    conn
    |> add_breadcrumb(name: "Test page", url: conn.request_path)
    |> assign(:socket, conn)
    |> assign(:layout_value, layout)
    |> put_layout(layout)
    |> render("test_page.html")
  end

  # List of font awesome icons
  @spec falist(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def falist(conn, _params) do
    conn
    |> render("falist.html")
  end
end
