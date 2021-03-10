defmodule CentralWeb.Logging.AuditLogController do
  use CentralWeb, :controller

  # alias Central.Logging.AuditLog
  alias Central.Logging
  alias Central.Logging.AuditLogLib

  plug :add_breadcrumb, name: 'Logging', url: '/logging'
  plug :add_breadcrumb, name: 'Audit', url: '/logging/audit'

  plug Bodyguard.Plug.Authorize,
    policy: Central.Admin,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug AssignPlug,
    sidemenu_active: "logging"

  def index(conn, params) do
    logs = Logging.list_audit_logs(order: "Newest first")
    # |> AuditLogLib.search(:groups, conn.assigns[:memberships])
    # |> AuditLogLib.preload_user

    conn
    |> assign(:show_search, Map.has_key?(params, "search"))
    |> assign(:params, form_params())
    |> assign(:actions, AuditLogLib.list_audit_types())
    |> assign(:logs, logs)
    |> render("index.html")
  end

  def search(conn, %{"search" => params}) do
    params = form_params(params)

    logs =
      Logging.list_audit_logs(
        search: [
          action: params["action"],
          user_id: params["user_id"],
          group_id: params["group_id"]
        ],
        order: "Newest first",
        limit: params["limit"]
      )

    # |> AuditLogLib.search(:groups, conn.assigns[:memberships])
    # |> AuditLogLib.preload_user
    # |> AuditLogLib.search(:action, params["action"])
    # |> AuditLogLib.search(:account_user, params["account_user"])
    # |> AuditLogLib.order(params["order"])
    # |> limit_query(params["limit"], 200)
    # |> Repo.all

    conn
    |> assign(:show_search, "hidden")
    |> assign(:params, params)
    |> assign(:actions, AuditLogLib.list_audit_types())
    |> assign(:logs, logs)
    |> render("index.html")
  end

  def show(conn, %{"id" => id}) do
    log = Logging.get_audit_log!(id, joins: [:user, :group])

    conn
    |> assign(:log, log)
    |> render("show.html")
  end

  defp form_params(params \\ %{}) do
    %{
      "action" => Map.get(params, "action", ""),
      "user_id" => Map.get(params, "account_user", "") |> get_hash_id,
      "account_user" => Map.get(params, "account_user", ""),
      "order" => Map.get(params, "order", "Newest first"),
      "limit" => Map.get(params, "limit", "50")
    }
  end
end
