defmodule CentralWeb.Account.GeneralController do
  use CentralWeb, :controller

  plug :add_breadcrumb, name: 'Account', url: '/account'

  def index(conn, _params) do
    conn
    |> render("index.html")
  end
end
