defmodule CentralWeb.Logging.ErrorLogController do
  use CentralWeb, :controller

  alias Central.Logging
  # alias Central.Logging.ErrorLog

  # alias Central.Logging.ErrorLogLib

  plug Bodyguard.Plug.Authorize,
    policy: Central.Logging.ErrorLog,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug :add_breadcrumb, name: 'Admin', url: '/admin'
  plug :add_breadcrumb, name: 'Tools', url: '/admin/tools'
  plug :add_breadcrumb, name: 'Error logs', url: '/logging/error_logs'

  def index(conn, _params) do
    logs =
      Logging.list_error_logs(
        joins: [:users],
        order: "Newest first"
      )

    conn
    |> assign(:logs, logs)
    |> render("index.html")
  end

  def show(conn, %{"id" => id}) do
    log = Logging.get_error_log!(id, joins: [:users])

    conn
    |> assign(:log, log)
    |> render("show.html")
  end

  def delete(conn, %{"id" => id}) do
    error_log = Logging.get_error_log!(id)
    {:ok, _error_log} = Logging.delete_error_log(error_log)

    conn
    |> put_flash(:success, "Error log deleted successfully.")
    |> redirect(to: Routes.logging_error_log_path(conn, :index))
  end

  def delete_all_form(conn, _params) do
    render(conn, "delete_all.html")
  end

  def delete_all_post(conn, _params) do
    Logging.delete_all_error_logs()

    conn
    |> put_flash(:success, "Error logs deleted successfully.")
    |> redirect(to: Routes.logging_error_log_path(conn, :index))
  end
end
