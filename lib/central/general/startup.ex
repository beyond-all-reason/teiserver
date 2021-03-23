defmodule Central.General.Startup do
  use CentralWeb, :startup

  def startup do
    QuickAction.add_items([
      %{
        label: "Admin index",
        icons: [Central.Admin.AdminLib.icon(), :list],
        url: "/admin",
        permissions: "admin.admin.limited"
      },
      %{
        label: "Tools",
        icons: [Central.Admin.ToolLib.icon()],
        url: "/admin/tools",
        permissions: "admin.dev.developer"
      },
      %{
        label: "List users",
        icons: [Central.Account.UserLib.icon(), :list],
        input: "s",
        method: "get",
        placeholder: "Search username and/or email",
        url: "/admin/users",
        permissions: "admin.admin.limited"
      },
      %{
        label: "List groups",
        icons: [Central.Account.GroupLib.icon(), :list],
        input: "s",
        method: "get",
        placeholder: "Search name",
        url: "/admin/groups",
        permissions: "admin.admin.limited"
      },
      %{
        label: "Error logs",
        icons: [Central.Logging.ErrorLogLib.icon(), :list],
        url: "/logging/error_logs",
        permissions: "admin.dev.developer"
      },
      %{
        label: "Audit logs",
        icons: [Central.Logging.AuditLogLib.icon(), :list],
        url: "/logging/audit",
        permissions: "admin.dev.developer"
      },
      %{
        label: "Aggregate logs",
        icons: [Central.Logging.AggregateViewLogLib.icon(), :list],
        url: "/logging/aggregate_views",
        permissions: "admin.dev.developer"
      },
      %{
        label: "Page view logs",
        icons: [Central.Logging.PageViewLogLib.icon(), :list],
        url: "/logging/page_views",
        permissions: "admin.dev.developer"
      },
      %{
        label: "Coverage",
        icons: ["far fa-percent"],
        url: "/admin/tools/coverage",
        permissions: "admin.dev.developer"
      },
      %{label: "Home", icons: ["far fa-home"], url: "/"}
    ])

    add_user_config_type(%{
      key: "general.Rate limit",
      section: "General",
      type: "integer",
      visible: false,
      permissions: ["admin.dev.developer"],
      description: "Page rate limit per minute",
      opts: [],
      default: nil
    })

    add_user_config_type(%{
      key: "general.User message",
      section: "General",
      type: "boolean",
      visible: false,
      permissions: ["admin.dev.developer"],
      description: "A message displayed on every page the user visits",
      opts: [],
      default: nil
    })

    add_user_config_type(%{
      key: "module.Quick action",
      section: "Modules",
      type: "boolean",
      visible: true,
      permissions: [],
      description: "Enables the 'Quick Action' shortcut: Ctrl + .",
      opts: [],
      default: nil
    })

    add_user_config_type(%{
      key: "general.Homepage",
      section: "General",
      type: "string",
      visible: true,
      permissions: [],
      description: "Sets the default homepage for when you first log in",
      opts: [],
      default: "/"
    })

    add_user_config_type(%{
      key: "general.Sidebar",
      section: "General",
      type: "boolean",
      visible: true,
      permissions: [],
      description: "Shows the sidebar menu",
      opts: [],
      default: true
    })

    add_user_config_type(%{
      key: "general.Screen size",
      section: "General",
      type: "string",
      visible: false,
      permissions: ["admin.dev.developer"],
      description:
        "Last recoreded screen size of the user, used for sizing certain windows accordingly",
      opts: [],
      default: nil
    })

    add_user_config_type(%{
      key: "general.Advanced configs",
      section: "General",
      type: "boolean",
      visible: false,
      permissions: ["admin.dev.developer"],
      description:
        "Changes the default behaviour of showing or hiding advanced options on the forms supporting them.",
      opts: [],
      default: false
    })

    add_permission_set("admin", "debug", ~w(debug))
    add_permission_set("admin", "dev", ~w(developer structure))
    add_permission_set("admin", "admin", ~w(limited full))
    add_permission_set("admin", "report", ~w(show update delete report))
    add_permission_set("admin", "user", ~w(show create update delete report))
    add_permission_set("admin", "group", ~w(show create update delete report config))

  end
end
