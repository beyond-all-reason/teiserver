defmodule CentralWeb.Logging.GeneralController do
  use CentralWeb, :controller

  # alias Central.Logging.AuditLog
  # import Central.Logging.AuditLogLib

  # plug :add_breadcrumb, name: 'Alacrity', url: '/'
  plug :add_breadcrumb, name: 'Admin', url: '/admin'
  plug :add_breadcrumb, name: 'Logging', url: '/logging'

  plug Bodyguard.Plug.Authorize,
    policy: Central.Logging.LoggingLib,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
