defmodule Central.Logging.Startup do
  use CentralWeb, :startup

  def startup do
    add_permission_set("logging", "page_view", ~w(show delete report))
    add_permission_set("logging", "aggregrate", ~w(show delete report))
    add_permission_set("logging", "audit", ~w(show delete report))
    add_permission_set("logging", "error", ~w(show delete report))

    # HookLib.register_events([
    #   %Event{
    #     name: "logging.Page view log",
    #     description: "Triggered when a user within your admin group loads a page",

    #     permissions: ["logging.page_view"],

    #     icons: [
    #       CentralWeb.Logging.GeneralHelper.icon(),
    #       Central.Logging.PageViewLogHelper.icon(),
    #       "far fa-plus"
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
