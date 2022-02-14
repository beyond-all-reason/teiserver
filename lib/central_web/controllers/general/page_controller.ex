defmodule CentralWeb.General.PageController do
  use CentralWeb, :controller

  def index(conn, _params) do
    maybe_user = Guardian.Plug.current_resource(conn)

    if maybe_user do
      render(conn, "auth_index.html")
    else
      conn
      |> put_layout("unauth.html")
      |> render("index.html")
    end
  end

  def recache(conn, _params) do
    Central.Account.recache_user(conn.current_user)
    {_, redirect} = List.keyfind(conn.req_headers, "referer", 0)

    conn
    |> redirect(external: redirect)
  end

  def browser_info(conn, _params) do
    conn
    |> render("browser_info.html")
  end
end
