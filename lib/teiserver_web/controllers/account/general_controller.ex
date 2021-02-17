defmodule TeiserverWeb.Account.GeneralController do
  use CentralWeb, :controller

  plug :add_breadcrumb, name: 'Teiserver', url: '/teiserver'
  plug :add_breadcrumb, name: 'Account', url: '/teiserver/account'

  def index(conn, _params) do
    render(conn, "index.html")
  end
end