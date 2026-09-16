defmodule TeiserverWeb.LoggingLive.AuditLog.Show do
  @moduledoc false
  alias Teiserver.Helper.QueryHelpers
  alias Teiserver.Logging.AuditLogQueries
  alias Teiserver.Repo
  alias TeiserverWeb.LoggingLive.AuditLogComponents

  use TeiserverWeb, :live_view

  @impl LiveView
  def mount(%{"id" => id}, _session, socket) do
    audit_log =
      AuditLogQueries.audit_logs()
      |> AuditLogQueries.where_id(id)
      |> AuditLogQueries.load_user()
      |> QueryHelpers.limit_query(1)
      |> Repo.one()

    if audit_log do
      socket
      |> assign(:page_title, "Show Audit Log")
      |> assign(audit_log: audit_log)
      |> ok()
    else
      socket
      |> redirect(to: ~p"/logging/audit_logs")
      |> put_flash(:info, "No log found")
      |> ok()
    end
  end

  @impl Phoenix.LiveView
  def handle_params(_params, _url, socket) do
    socket
    |> noreply()
  end

  @impl Phoenix.LiveView
  def handle_event(_event_text, _event_data, %{assigns: _assigns} = socket) do
    socket
    |> noreply()
  end
end
