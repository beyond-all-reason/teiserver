defmodule Teiserver.TeiserverConfigs do
  @moduledoc false
  import Central.Config, only: [add_site_config_type: 1, add_user_config_type: 1]

  @spec teiserver_configs :: any
  def teiserver_configs do
    site_configs()
    user_configs()
  end

  @spec site_configs :: any
  defp site_configs do
    add_site_config_type(%{
      key: "system.Process matches",
      section: "Background tasks",
      type: "boolean",
      permissions: ["teiserver.admin"],
      description: "Enable/disable post processing of matches",
      opts: [],
      default: true,

      value_label: "Enable"
    })

    add_site_config_type(%{
      key: "matchmaking.Use ready check",
      section: "Matchmaking",
      type: "boolean",
      permissions: ["teiserver.admin"],
      description: "When set to true matchmaking uses a ready check",
      opts: [],
      default: true,
      value_label: "Require ready check"
    })

    add_site_config_type(%{
      key: "bots.Flag",
      section: "Bots",
      type: "string",
      permissions: ["teiserver.staff.server"],
      description: "Country code flag used by bots managed by the server",
      opts: [],
      default: "GB",
      value_label: ""
    })

    add_site_config_type(%{
      key: "system.Use geoip",
      section: "System",
      type: "boolean",
      permissions: ["teiserver.admin"],
      description: "When enabled you will use geoip for country code lookups",
      opts: [],
      default: true,
      value_label: ""
    })

    add_site_config_type(%{
      key: "system.Enable user registration",
      section: "System",
      type: "boolean",
      permissions: ["teiserver.admin"],
      description: "When enabled users are able to register",
      opts: [],
      default: true,
      value_label: ""
    })

    add_site_config_type(%{
      key: "system.User limit",
      section: "System",
      type: "integer",
      permissions: ["teiserver.admin"],
      description: "The cap for number of concurrent users, set to 0 to be infinite",
      opts: [],
      default: 1000,
      value_label: ""
    })

    add_site_config_type(%{
      key: "teiserver.Spring flood rate limit count",
      section: "Protocol",
      type: "integer",
      permissions: ["teiserver.admin"],
      description: "The number of commands required to trip flood protection for Spring",
      opts: [],
      default: 20
    })

    add_site_config_type(%{
      key: "teiserver.Spring flood rate window size",
      section: "Protocol",
      type: "integer",
      permissions: ["teiserver.admin"],
      description: "The size of the window in seconds for flood protection to trip for Spring",
      opts: [],
      default: 6
    })

    add_site_config_type(%{
      key: "teiserver.Tachyon flood rate limit count",
      section: "Protocol",
      type: "integer",
      permissions: ["teiserver.admin"],
      description: "The number of commands required to trip flood protection for Tachyon",
      opts: [],
      default: 20
    })

    add_site_config_type(%{
      key: "teiserver.Tachyon flood rate window size",
      section: "Protocol",
      type: "integer",
      permissions: ["teiserver.admin"],
      description: "The size of the window in seconds for flood protection to trip for Tachyon",
      opts: [],
      default: 6
    })

    add_site_config_type(%{
      key: "teiserver.Ring flood rate limit count",
      section: "Protocol",
      type: "integer",
      permissions: ["teiserver.admin"],
      description: "The number of rings required to trip flood protection",
      opts: [],
      default: 5
    })

    add_site_config_type(%{
      key: "teiserver.Ring flood rate window size",
      section: "Protocol",
      type: "integer",
      permissions: ["teiserver.admin"],
      description: "The size of the window in seconds for flood protection to trip for rings",
      opts: [],
      default: 10
    })

    add_site_config_type(%{
      key: "teiserver.Post login action delay",
      section: "Protocol",
      type: "integer",
      permissions: ["teiserver.admin"],
      description: "The time in milliseconds to wait until doing something when a user logs in (e.g. sending a message)",
      opts: [],
      default: 2500
    })

    add_site_config_type(%{
      key: "teiserver.Warning acknowledge prompt",
      section: "Moderation",
      type: "string",
      permissions: ["teiserver.admin.account"],
      description: "The string used to request acknowledgement of warnings",
      opts: [],
      default: "Acknowledge this with 'I acknowledge this' to resume play"
    })

    add_site_config_type(%{
      key: "teiserver.Warning acknowledge response",
      section: "Moderation",
      type: "string",
      permissions: ["teiserver.admin.account"],
      description: "The response string expected to acknowledge the warning",
      opts: [],
      default: "I acknowledge this"
    })

    add_site_config_type(%{
      key: "teiserver.Automod action delay",
      section: "Moderation",
      type: "integer",
      permissions: ["teiserver.admin"],
      description: "The delay in seconds after a user logs in for the automod to check on them.",
      opts: [],
      default: 120
    })

    add_site_config_type(%{
      key: "teiserver.Require HW data to play",
      section: "Moderation",
      type: "boolean",
      permissions: ["teiserver.admin"],
      description: "Prevents someone from being a player if they don't have a HW hash yet.",
      opts: [],
      default: false
    })

    add_site_config_type(%{
      key: "teiserver.Require Chobby data to play",
      section: "Moderation",
      type: "boolean",
      permissions: ["teiserver.admin"],
      description: "Prevents someone from being a player if they don't have a Chobby key yet.",
      opts: [],
      default: false
    })

    add_site_config_type(%{
      key: "teiserver.Enable accolades",
      section: "Accolades",
      type: "boolean",
      permissions: ["teiserver.admin.account"],
      description: "When enabled, players will be offered the chance to bestow accolades to each other.",
      opts: [],
      default: true
    })

    add_site_config_type(%{
      key: "teiserver.Inform of new accolades",
      section: "Accolades",
      type: "boolean",
      permissions: ["teiserver.admin.account"],
      description: "When set to true, players will be informed when they get a new accolade",
      opts: [],
      default: false
    })

    add_site_config_type(%{
      key: "teiserver.Require email verification",
      section: "Registrations",
      type: "boolean",
      permissions: ["admin.dev.developer"],
      description: "When enabled, users must verify their account via email",
      opts: [],
      default: true
    })

    add_site_config_type(%{
      key: "teiserver.Enable registrations",
      section: "Registrations",
      type: "boolean",
      permissions: ["admin.dev.developer"],
      description: "Allows users to register",
      opts: [],
      default: true
    })

    add_site_config_type(%{
      key: "teiserver.Require Chobby registration",
      section: "Registrations",
      type: "boolean",
      permissions: ["admin.dev.developer"],
      description: "Prevents users registering with anything other than Chobby",
      opts: [],
      default: false
    })

    add_site_config_type(%{
      key: "teiserver.Username max length",
      section: "Registrations",
      type: "integer",
      permissions: ["teiserver.admin"],
      description: "The maximum number of characters allowed in a username.",
      opts: [],
      default: 20
    })

    add_site_config_type(%{
      key: "teiserver.Require Chobby login",
      section: "Registrations",
      type: "boolean",
      permissions: ["admin.dev.developer"],
      description: "Prevents users logging in with anything other than Chobby",
      opts: [],
      default: false
    })

    add_site_config_type(%{
      key: "teiserver.Bridge from discord",
      section: "Discord",
      type: "boolean",
      permissions: ["teiserver.staff.moderator"],
      description: "Enables bridging from discord to in-lobby channels",
      opts: [],
      default: true
    })

    add_site_config_type(%{
      key: "teiserver.Bridge from server",
      section: "Discord",
      type: "boolean",
      permissions: ["teiserver.staff.moderator"],
      description: "Enables bridging from in-lobby channels to discord",
      opts: [],
      default: true
    })

    add_site_config_type(%{
      key: "teiserver.Bridge player numbers",
      section: "Discord",
      type: "boolean",
      permissions: ["teiserver.admin"],
      description: "Enables bridging of channel names to discord",
      opts: [],
      default: true
    })

    add_site_config_type(%{
      key: "teiserver.Default player limit",
      section: "Lobbies",
      type: "integer",
      permissions: ["teiserver.admin"],
      description: "The default player limit for lobbies",
      opts: [],
      default: 16
    })

    add_site_config_type(%{
      key: "teiserver.Max deviation",
      section: "Lobbies",
      type: "integer",
      permissions: ["teiserver.admin"],
      description: "The maximum deviation in mixed party-solo balance before it reverts to purely solo balance",
      opts: [],
      default: 10
    })

    add_site_config_type(%{
      key: "teiserver.Enable server balance",
      section: "Lobbies",
      type: "boolean",
      permissions: ["teiserver.admin"],
      description: "Enable server-side balance for lobbies",
      opts: [],
      default: true
    })

    add_site_config_type(%{
      key: "teiserver.Curse word score A",
      section: "Lobbies",
      type: "integer",
      permissions: ["teiserver.admin.account"],
      description: "Points for the harshest of curse words",
      opts: [],
      default: 10
    })

    add_site_config_type(%{
      key: "teiserver.Curse word score B",
      section: "Lobbies",
      type: "integer",
      permissions: ["teiserver.admin.account"],
      description: "Points for the middlest of curse words",
      opts: [],
      default: 4
    })

    add_site_config_type(%{
      key: "teiserver.Curse word score C",
      section: "Lobbies",
      type: "integer",
      permissions: ["teiserver.admin.account"],
      description: "Points for the lightest of curse words",
      opts: [],
      default: 1
    })
  end

  @spec user_configs() :: any
  defp user_configs() do
    add_user_config_type(%{
      key: "teiserver.Show flag",
      section: "Teiserver account",
      type: "boolean",
      visible: true,
      permissions: ["teiserver"],
      description:
        "When checked the flag associated with your IP will be displayed. If unchecked your flag will be blank. This will take effect next time you login with your client.",
      opts: [],
      default: true
    })

    add_user_config_type(%{
      key: "teiserver.Discord notifications",
      section: "Teiserver account",
      type: "boolean",
      visible: true,
      permissions: ["teiserver"],
      description:
        "When checked you will receive discord messages from the Teiserver bridge bot for various in-lobby events. When disabled you will receive no notifications even if the others are enabled.",
      opts: [],
      default: true
    })

    add_user_config_type(%{
      key: "teiserver.Notify - Exited the queue",
      section: "Teiserver account",
      type: "boolean",
      visible: true,
      permissions: ["teiserver"],
      description:
        "You will be messaged when you move from being in the queue to being a player",
      opts: [],
      default: true
    })

    add_user_config_type(%{
      key: "teiserver.Notify - Game start",
      section: "Teiserver account",
      type: "boolean",
      visible: true,
      permissions: ["teiserver"],
      description:
        "You will be messaged when a lobby you are a player in starts",
      opts: [],
      default: true
    })
  end
end
