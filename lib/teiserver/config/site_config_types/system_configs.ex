defmodule Teiserver.Config.SiteConfigTypes.SystemConfigs do
  @moduledoc false
  import Teiserver.Config, only: [add_site_config_type: 1]

  @spec create() :: :ok
  def create() do
    add_site_config_type(%{
      key: "system.Redirect url",
      section: "System",
      type: "string",
      permissions: ["Admin"],
      description: "A redirect URL for those accessing the old server",
      value_label: "The URL for the redirect"
    })

    add_site_config_type(%{
      key: "system.Disconnect unauthenticated sockets",
      section: "System",
      type: "boolean",
      default: false,
      permissions: ["Admin"],
      description: "When enabled sockets not authenticated after 60 seconds will be disconnected",
      value_label: "Disconnect unauthenticated sockets"
    })

    add_site_config_type(%{
      key: "system.Process matches",
      section: "System",
      type: "boolean",
      permissions: ["Admin"],
      description: "Enable/disable post processing of matches",
      default: true,
      value_label: "Enable"
    })

    add_site_config_type(%{
      key: "system.Use geoip",
      section: "System",
      type: "boolean",
      permissions: ["Admin"],
      description: "When enabled you will use geoip for country code lookups",
      default: true,
      value_label: ""
    })

    add_site_config_type(%{
      key: "system.Run daily cleanup task",
      section: "System",
      type: "boolean",
      permissions: ["Admin"],
      description: "When enabled daily cleanup task will be ran every day at 8 am",
      default: true,
      value_label: "Enabled"
    })
  end
end
