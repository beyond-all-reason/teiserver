defmodule CentralWeb.Logging.ErrorLogController do
  use CentralWeb, :controller

  alias Central.Logging

  plug Bodyguard.Plug.Authorize,
    policy: Central.Logging.ErrorLog,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug :add_breadcrumb, name: 'Logging', url: '/logging'
  plug :add_breadcrumb, name: 'Errors', url: '/logging/error_logs'

  plug AssignPlug,
    sidemenu_active: "logging"

  @spec index(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
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

  @spec show(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    log = Logging.get_error_log!(id, joins: [:users])

    conn
    |> assign(:log, log)
    |> render("show.html")
  end

  @spec delete(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    error_log = Logging.get_error_log!(id)
    {:ok, _error_log} = Logging.delete_error_log(error_log)

    conn
    |> put_flash(:success, "Error log deleted successfully.")
    |> redirect(to: Routes.logging_error_log_path(conn, :index))
  end

  @spec delete_all_form(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def delete_all_form(conn, _params) do
    render(conn, "delete_all.html")
  end

  @spec delete_all_post(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def delete_all_post(conn, _params) do
    Logging.delete_all_error_logs()

    conn
    |> put_flash(:success, "Error logs deleted successfully.")
    |> redirect(to: Routes.logging_error_log_path(conn, :index))
  end
end
