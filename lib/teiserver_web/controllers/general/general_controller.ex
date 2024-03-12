defmodule BarserverWeb.General.GeneralController do
  use BarserverWeb, :controller

  plug(AssignPlug,
    site_menu_active: "teiserver",
    sub_menu_active: "teiserver"
  )

  plug(Barserver.ServerUserPlug)

  @spec index(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def index(conn, _params) do
    conn
    |> redirect(to: ~p"/")
  end

  @spec gdpr(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def gdpr(conn, _params) do
    host = Application.get_env(:teiserver, BarserverWeb.Endpoint)[:url][:host]
    website_url = "https://#{host}"

    conn
    |> assign(:game_name, Application.get_env(:teiserver, Barserver)[:game_name])
    |> assign(:game_name_short, Application.get_env(:teiserver, Barserver)[:game_name_short])
    |> assign(:main_website, Application.get_env(:teiserver, Barserver)[:main_website])
    |> assign(:github_repo, Application.get_env(:teiserver, Barserver)[:github_repo])
    |> assign(:website_url, website_url)
    |> assign(:privacy_email, Application.get_env(:teiserver, Barserver)[:privacy_email])
    |> render("gdpr.html")
  end

  @spec code_of_conduct(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def code_of_conduct(conn, _params) do
    conn
    |> render("code_of_conduct.html")
  end
end
