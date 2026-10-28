defmodule TeiserverWeb.AdminLive.SiteConfig.Show do
  @moduledoc false
  alias Teiserver.Config
  alias Teiserver.Logging.AuditLogQueries
  alias Teiserver.Repo
  alias TeiserverWeb.AdminLive.SiteConfigComponents

  use TeiserverWeb, :live_view

  @impl LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl LiveView
  def handle_params(%{"key" => key}, _url, socket) do
    config_type = Config.get_site_config_type(key)
    value = Config.get_site_config_val(key)

    socket
    |> assign(
      page_title: page_title(socket.assigns.live_action),
      config_type: config_type,
      key: key,
      value: value
    )
    |> get_audit_logs()
    |> noreply()
  end

  defp page_title(:show), do: "Show Site config"
  defp page_title(:edit), do: "Edit Site config"

  defp get_audit_logs(%{assigns: %{key: key}} = socket) do
    audit_logs =
      AuditLogQueries.audit_logs()
      |> AuditLogQueries.where_action("Update SiteConfig")
      |> AuditLogQueries.where_details_equal("key", key)
      |> AuditLogQueries.load_user()
      |> AuditLogQueries.order_by_inserted_at(:desc)
      |> QueryHelpers.limit_query(50)
      |> Repo.all()

    socket
    |> assign(audit_logs: audit_logs)
  end
end
