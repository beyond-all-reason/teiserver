defmodule Central.Admin.Startup do
  @moduledoc false
  use CentralWeb, :startup

  def startup do
    add_permission_set("debug", "debug", ~w(debug))
    add_permission_set("admin", "user", ~w(show create update delete report))
    add_permission_set("admin", "dev", ~w(developer structure))
    add_permission_set("admin", "group", ~w(show create update delete report))
    add_permission_set("admin", "admin", ~w(limited full))

    add_site_config_type(%{
      key: "user.Enable account group pages",
      section: "User permissions",
      type: "boolean",
      permissions: ["teiserver.admin"],
      description: "Users are able to view (and edit) their group memberships.",
      opts: [],
      default: true,

      value_label: "Enable account group pages"
    })

    add_site_config_type(%{
      key: "user.Enable user registrations",
      section: "User permissions",
      type: "select",
      permissions: ["teiserver.admin"],
      description: "Users are able to view (and edit) their group memberships.",
      opts: [choices: ["Allowed", "Link only", "Disabled"]],
      default: "Allowed",

      value_label: "Enable account group pages"
    })

    add_site_config_type(%{
      key: "site.Main site link",
      section: "Site management",
      type: "string",
      permissions: ["teiserver.admin"],
      description: "A link to an external site if this is not your main site.",
      opts: [],
      default: "",

      value_label: "Link"
    })

    ConCache.put(:application_metadata_cache, :app_startup_datetime, Timex.now())
  end
end
