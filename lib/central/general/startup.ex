defmodule Central.General.Startup do
  @moduledoc false
  use CentralWeb, :startup

  @spec startup :: :ok
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
        label: "Coverage",
        icons: ["fa-regular fa-percent"],
        url: "/admin/tools/coverage",
        permissions: "admin.dev.developer"
      },
      %{
        label: "Home",
        icons: ["fa-regular fa-home"],
        url: "/"
      }
    ])

    add_user_config_type(%{
      key: "general.Colour scheme",
      section: "Interface",
      type: "select",
      visible: true,
      permissions: [],
      opts: [choices: ["Site default", "Light", "Dark"]],
      default: "Site default",

      description: "The colour scheme used by the site."
    })

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
      default: true,
      value_label: "Enable quick action shortcut"
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

    # Need to get the timezones
    zones = "timedatectl"
      |> System.cmd(["list-timezones"])
      |> elem(0)
      |> String.trim
      |> String.split("\n")

    add_user_config_type(%{
      key: "general.Timezone",
      section: "General",
      type: "select",
      visible: true,
      permissions: [],
      description:
        "The timezone you are present in for conversion of timestamps.",
      opts: [
        choices: zones
      ],
      default: Application.get_env(:central, Central.Config)[:defaults].tz
    })

    add_user_config_type(%{
      key: "general.Language",
      section: "General",
      type: "select",
      visible: false,
      permissions: [],
      description:
        "Language used on the site (currently only English).",
      opts: ~w(English),
      default: false
    })


    add_site_config_type(%{
      key: "user.Default light mode",
      section: "Interface",
      type: "boolean",
      permissions: ["admin.admin"],
      description: "When set to true the default view for users is light mode.",
      opts: [],
      default: false,

      value_label: "Light mode as default"
    })

    Central.store_put(:application_metadata_cache, "random_names_1", ~w(serene energised humble auspicious decisive exemplary cheerful determined playful spry springy))
    Central.store_put(:application_metadata_cache, "random_names_2", ~w(maroon magenta lemon aqua cerulean amber beige lavender indigo))
    Central.store_put(:application_metadata_cache, "random_names_3", ~w(hamster gerbil cat dog falcon eagle mole fox tiger panda elephant lion cow dove whale dolphin squid dragon snake platypus badger))

    add_permission_set("admin", "debug", ~w(debug))
    add_permission_set("admin", "dev", ~w(developer structure))
    add_permission_set("admin", "admin", ~w(limited full))
    add_permission_set("admin", "report", ~w(show update delete report))
    add_permission_set("admin", "user", ~w(show create update delete report))
    add_permission_set("admin", "group", ~w(show create update delete report config))
  end
end
