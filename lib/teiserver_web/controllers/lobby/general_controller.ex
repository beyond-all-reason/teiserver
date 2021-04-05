defmodule TeiserverWeb.Lobby.GeneralController do
  use CentralWeb, :controller

  plug(:add_breadcrumb, name: 'Teiserver', url: '/teiserver')

  plug(AssignPlug,
    sidemenu_active: "teiserver"
  )

  plug(Teiserver.ServerUserPlug)

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def spass(conn, %{"p" => p}) do
    p = Teiserver.User.spring_md5_password(p)
    conn
    |> assign(:p, p)
    |> render("spass.html")
  end

  def spass(conn, _params) do
    conn
    |> assign(:p, nil)
    |> render("spass.html")
  end
end
