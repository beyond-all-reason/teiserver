defmodule CentralWeb.Account.GeneralController do
  use CentralWeb, :controller

  plug :add_breadcrumb, name: 'Account', url: '/account'

  plug(AssignPlug,
    site_menu_active: "central_account",
    sub_menu_active: "general"
  )

  def index(conn, _params) do
    conn
    |> render("index.html")
  end
end
