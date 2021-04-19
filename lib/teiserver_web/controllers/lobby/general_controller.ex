defmodule TeiserverWeb.Lobby.GeneralController do
  use CentralWeb, :controller

  plug(:add_breadcrumb, name: 'Teiserver', url: '/teiserver')

  plug(AssignPlug,
    sidemenu_active: "teiserver"
  )

  plug(Teiserver.ServerUserPlug)

  @spec index(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def index(conn, _params) do
    render(conn, "index.html")
  end

  @spec spass(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def spass(conn, %{"p" => p}) do
    p = Teiserver.User.spring_md5_password(p)
    conn
    |> assign(:p, p)
    |> render("spass.html")
  end

  @spec spass(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def spass(conn, _params) do
    conn
    |> assign(:p, nil)
    |> render("spass.html")
  end
end
