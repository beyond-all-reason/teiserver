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

    Central.store_put(
      :application_metadata_cache,
      "random_names_1",
      ~w(serene energised humble auspicious decisive exemplary cheerful determined playful spry springy)
    )

    Central.store_put(:application_metadata_cache, "random_names_2", ~w(
      maroon cherry rose ruby
      amber carrot
      lemon beige
      mint lime cadmium
      aqua cerulean
      lavender indigo
      magenta amethyst
    ))

    Central.store_put(
      :application_metadata_cache,
      "random_names_3",
      ~w(hamster gerbil cat dog falcon eagle mole fox tiger panda elephant lion cow dove whale dolphin squid dragon snake platypus badger)
    )

    add_permission_set("admin", "debug", ~w(debug))
    add_permission_set("admin", "dev", ~w(developer structure))
    add_permission_set("admin", "admin", ~w(limited full))
    add_permission_set("admin", "report", ~w(show update delete report))
    add_permission_set("admin", "user", ~w(show create update delete report))
    add_permission_set("admin", "group", ~w(show create update delete report config))
  end
end
