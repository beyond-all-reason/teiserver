defmodule Teiserver.Logging.Startup do
  @moduledoc false
  use CentralWeb, :startup

  def startup do
    add_permission_set("logging", "page_view", ~w(show delete report))
    add_permission_set("logging", "aggregate", ~w(show delete report))
    add_permission_set("logging", "audit", ~w(show delete report))
    add_permission_set("logging", "error", ~w(show delete report))
    add_permission_set("logging", "live", ~w(show))

    QuickAction.add_items([
      %{
        label: "Live view dashboard",
        icons: ["fa-regular fa-tachometer-alt", :list],
        url: "/logging/live/dashboard",
        permissions: "logging.live"
      },
      %{
        label: "Audit logs",
        icons: [Teiserver.Logging.AuditLogLib.icon(), :list],
        url: "/logging/audit",
        permissions: "logging.audit"
      },
      %{
        label: "Aggregate logs",
        icons: [Teiserver.Logging.AggregateViewLogLib.icon(), :list],
        url: "/logging/aggregate_views",
        permissions: "logging.agggregate"
      },
      %{
        label: "Page view logs",
        icons: [Teiserver.Logging.PageViewLogLib.icon(), :list],
        url: "/logging/page_views",
        permissions: "logging.page_view"
      }
    ])
  end
end
