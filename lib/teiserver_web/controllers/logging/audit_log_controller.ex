defmodule TeiserverWeb.Logging.AuditLogController do
  use TeiserverWeb, :controller

  # alias Teiserver.Logging.AuditLog
  alias Teiserver.Logging
  alias Teiserver.Logging.AuditLogLib

  import Teiserver.Helper.StringHelper, only: [get_hash_id: 1]

  plug :add_breadcrumb, name: "Logging", url: "/logging"
  plug :add_breadcrumb, name: "Audit", url: "/logging/audit"

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Logging.AuditLog,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}

  plug(AssignPlug,
    site_menu_active: "logging",
    sub_menu_active: "audit"
  )

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    logs =
      Logging.list_audit_logs(
        joins: [:user],
        order_by: "Newest first"
      )

    conn
    |> assign(:show_search, Map.has_key?(params, "search"))
    |> assign(:params, form_params())
    |> assign(:actions, AuditLogLib.list_audit_types())
    |> assign(:logs, logs)
    |> render("index.html")
  end

  @spec search(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def search(conn, %{"search" => params}) do
    params = form_params(params)

    logs =
      Logging.list_audit_logs(
        search: [
          action: params["action"],
          user_id: params["user_id"]
        ],
        joins: [:user],
        order_by: "Newest first",
        limit: params["limit"]
      )

    conn
    |> assign(:show_search, "hidden")
    |> assign(:params, params)
    |> assign(:actions, AuditLogLib.list_audit_types())
    |> assign(:logs, logs)
    |> render("index.html")
  end

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    log = Logging.get_audit_log!(id, joins: [:user, :group])

    conn
    |> assign(:log, log)
    |> render("show.html")
  end

  @spec form_params(map()) :: map()
  defp form_params(params \\ %{}) do
    %{
      "action" => Map.get(params, "action", ""),
      "user_id" => Map.get(params, "account_user", "") |> get_hash_id(),
      "account_user" => Map.get(params, "account_user", ""),
      "order" => Map.get(params, "order", "Newest first"),
      "limit" => Map.get(params, "limit", "50")
    }
  end
end
