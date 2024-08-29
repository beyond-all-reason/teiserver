defmodule TeiserverWeb.General.GeneralController do
  use TeiserverWeb, :controller

  plug(AssignPlug,
    site_menu_active: "teiserver",
    sub_menu_active: "teiserver"
  )

  plug(Teiserver.ServerUserPlug)

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    conn
    |> redirect(to: ~p"/")
  end

  @spec gdpr(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def gdpr(conn, _params) do
    host = Application.get_env(:teiserver, TeiserverWeb.Endpoint)[:url][:host]
    website_url = "https://#{host}"

    conn
    |> assign(:game_name, Application.get_env(:teiserver, Teiserver)[:game_name])
    |> assign(:game_name_short, Application.get_env(:teiserver, Teiserver)[:game_name_short])
    |> assign(:main_website, Application.get_env(:teiserver, Teiserver)[:main_website])
    |> assign(:github_repo, Application.get_env(:teiserver, Teiserver)[:github_repo])
    |> assign(:website_url, website_url)
    |> assign(:privacy_email, Application.get_env(:teiserver, Teiserver)[:privacy_email])
    |> render("gdpr.html")
  end

  @spec code_of_conduct(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def code_of_conduct(conn, _params) do
    conn
    |> render("code_of_conduct.html")
  end
end
