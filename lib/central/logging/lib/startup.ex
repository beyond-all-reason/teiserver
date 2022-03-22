defmodule Central.Logging.Startup do
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
        label: "Error logs",
        icons: [Central.Logging.ErrorLogLib.icon(), :list],
        url: "/logging/error_logs",
        permissions: "logging.error"
      },
      %{
        label: "Audit logs",
        icons: [Central.Logging.AuditLogLib.icon(), :list],
        url: "/logging/audit",
        permissions: "logging.audit"
      },
      %{
        label: "Aggregate logs",
        icons: [Central.Logging.AggregateViewLogLib.icon(), :list],
        url: "/logging/aggregate_views",
        permissions: "logging.agggregate"
      },
      %{
        label: "Page view logs",
        icons: [Central.Logging.PageViewLogLib.icon(), :list],
        url: "/logging/page_views",
        permissions: "logging.page_view"
      }
    ])

    # HookLib.register_events([
    #   %Event{
    #     name: "logging.Page view log",
    #     description: "Triggered when a user within your admin group loads a page",

    #     permissions: ["logging.page_view"],

    #     icons: [
    #       CentralWeb.Logging.GeneralHelper.icon(),
    #       Central.Logging.PageViewLogHelper.icon(),
    #       "fa-regular fa-plus"
    #     ],
    #     colour: elem(Central.Logging.PageViewLogHelper.colours(), 0),

    #     onload: nil,#CentralWeb.Bedrock.PolicyHook.latest_policies,
    #     onload_defaults: %{},

    #     outputs: [:page_view_log],
    #     example: %{
    #       ip: "127.0.0.1",
    #       log_id: 101,
    #       path: "/dashboard/displays/1",
    #       timestamp: "18:06:50",
    #       user_id: 1,
    #       username: "Test user"
    #   }},
    # ])
  end
end
