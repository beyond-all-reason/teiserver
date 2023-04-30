defmodule Teiserver.TeiserverConfigs do
  @moduledoc false
  import Central.Config, only: [add_site_config_type: 1, add_user_config_type: 1]

  @spec teiserver_configs :: any
  def teiserver_configs do
    # User configs
    user_configs()

    # Site based configs
    site_configs()
    system_configs()
    login_configs()
    legacy_protocol_configs()
    moderation_configs()
    discord_configs()
    lobby_configs()
    debugging_configs()
  end

  @spec site_configs :: any
  defp site_configs do
    add_site_config_type(%{
      key: "matchmaking.Use ready check",
      section: "Matchmaking",
      type: "boolean",
      permissions: ["teiserver.admin"],
      description: "When set to true matchmaking uses a ready check",
      default: true,
      value_label: "Require ready check"
    })

    add_site_config_type(%{
      key: "bots.Flag",
      section: "Bots",
      type: "string",
      permissions: ["teiserver.staff.server"],
      description: "Country code flag used by bots managed by the server",
      default: "GB",
      value_label: ""
    })

    add_site_config_type(%{
      key: "teiserver.Enable accolades",
      section: "Accolades",
      type: "boolean",
      permissions: ["teiserver.admin.account"],
      description:
        "When enabled, players will be offered the chance to bestow accolades to each other.",
      default: true
    })

    add_site_config_type(%{
      key: "teiserver.Inform of new accolades",
      section: "Accolades",
      type: "boolean",
      permissions: ["teiserver.admin.account"],
      description: "When set to true, players will be informed when they get a new accolade",
      default: false
    })

    add_site_config_type(%{
      key: "teiserver.Require email verification",
      section: "Registrations",
      type: "boolean",
      permissions: ["admin.dev.developer"],
      description: "When enabled, users must verify their account via email",
      default: true
    })

    add_site_config_type(%{
      key: "teiserver.Enable registrations",
      section: "Registrations",
      type: "boolean",
      permissions: ["admin.dev.developer"],
      description: "Allows users to register",
      default: true
    })

    add_site_config_type(%{
      key: "teiserver.Require Chobby registration",
      section: "Registrations",
      type: "boolean",
      permissions: ["admin.dev.developer"],
      description: "Prevents users registering with anything other than Chobby",
      default: false
    })

    add_site_config_type(%{
      key: "teiserver.Username max length",
      section: "Registrations",
      type: "integer",
      permissions: ["teiserver.admin"],
      description: "The maximum number of characters allowed in a username.",
      default: 20
    })

    add_site_config_type(%{
      key: "teiserver.Require Chobby login",
      section: "Registrations",
      type: "boolean",
      permissions: ["admin.dev.developer"],
      description: "Prevents users logging in with anything other than Chobby",
      default: false
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
      default: true
    })

    add_user_config_type(%{
      key: "teiserver.Notify - Exited the queue",
      section: "Teiserver account",
      type: "boolean",
      visible: true,
      permissions: ["teiserver"],
      description: "You will be messaged when you move from being in the queue to being a player",
      default: true
    })

    add_user_config_type(%{
      key: "teiserver.Notify - Game start",
      section: "Teiserver account",
      type: "boolean",
      visible: true,
      permissions: ["teiserver"],
      description: "You will be messaged when a lobby you are a player in starts",
      default: true
    })
  end

  defp moderation_configs() do
    add_site_config_type(%{
      key: "teiserver.Warning acknowledge prompt",
      section: "Moderation",
      type: "string",
      permissions: ["teiserver.admin.account"],
      description: "The string used to request acknowledgement of warnings",
      default: "Acknowledge this with 'I acknowledge this' to resume play"
    })

    add_site_config_type(%{
      key: "teiserver.Warning acknowledge response",
      section: "Moderation",
      type: "string",
      permissions: ["teiserver.admin.account"],
      description: "The response string expected to acknowledge the warning",
      default: "I acknowledge this"
    })

    add_site_config_type(%{
      key: "teiserver.Automod action delay",
      section: "Moderation",
      type: "integer",
      permissions: ["teiserver.admin"],
      description: "The delay in seconds after a user logs in for the automod to check on them.",
      default: 120
    })

    add_site_config_type(%{
      key: "teiserver.Require HW data to play",
      section: "Moderation",
      type: "boolean",
      permissions: ["teiserver.admin"],
      description: "Prevents someone from being a player if they don't have a HW hash yet.",
      default: false
    })

    add_site_config_type(%{
      key: "teiserver.Require Chobby data to play",
      section: "Moderation",
      type: "boolean",
      permissions: ["teiserver.admin"],
      description: "Prevents someone from being a player if they don't have a Chobby key yet.",
      default: false
    })
  end

  defp legacy_protocol_configs() do
    add_site_config_type(%{
      key: "teiserver.Spring flood rate limit count",
      section: "Legacy protocol",
      type: "integer",
      permissions: ["teiserver.admin"],
      description: "The number of commands required to trip flood protection for Spring",
      default: 20
    })

    add_site_config_type(%{
      key: "teiserver.Spring flood rate window size",
      section: "Legacy protocol",
      type: "integer",
      permissions: ["teiserver.admin"],
      description: "The size of the window in seconds for flood protection to trip for Spring",
      default: 6
    })

    add_site_config_type(%{
      key: "teiserver.Tachyon flood rate limit count",
      section: "Legacy protocol",
      type: "integer",
      permissions: ["teiserver.admin"],
      description: "The number of commands required to trip flood protection for Tachyon",
      default: 20
    })

    add_site_config_type(%{
      key: "teiserver.Tachyon flood rate window size",
      section: "Legacy protocol",
      type: "integer",
      permissions: ["teiserver.admin"],
      description: "The size of the window in seconds for flood protection to trip for Tachyon",
      default: 6
    })

    add_site_config_type(%{
      key: "teiserver.Ring flood rate limit count",
      section: "Legacy protocol",
      type: "integer",
      permissions: ["teiserver.admin"],
      description: "The number of rings required to trip flood protection",
      default: 5
    })

    add_site_config_type(%{
      key: "teiserver.Ring flood rate window size",
      section: "Legacy protocol",
      type: "integer",
      permissions: ["teiserver.admin"],
      description: "The size of the window in seconds for flood protection to trip for rings",
      default: 10
    })

    add_site_config_type(%{
      key: "teiserver.Post login action delay",
      section: "Legacy protocol",
      type: "integer",
      permissions: ["teiserver.admin"],
      description:
        "The time in milliseconds to wait until doing something when a user logs in (e.g. sending a message)",
      default: 2500
    })
  end

  defp login_configs() do
    add_site_config_type(%{
      key: "system.Login limit count",
      section: "System",
      type: "integer",
      default: 3,
      permissions: ["teiserver.admin"],
      description: "How many times a user can attempt to login within the refresh window",
      value_label: "Login limit count"
    })

    add_site_config_type(%{
      key: "system.Post login delay",
      section: "System",
      type: "integer",
      default: 1000,
      permissions: ["teiserver.admin"],
      description: "The duration (ms) to pause the process after logging in",
      value_label: "Post login delay (ms)"
    })

    add_site_config_type(%{
      key: "system.Use login throttle",
      section: "System",
      type: "boolean",
      default: false,
      permissions: ["teiserver.admin"],
      description: "When enabled all login attempts will pass through the login throttle server",
      value_label: "Use login throttle"
    })

    add_site_config_type(%{
      key: "system.User limit",
      section: "System",
      type: "integer",
      permissions: ["teiserver.admin"],
      description: "The cap for number of concurrent users, set to 0 to be infinite",
      default: 1000,
      value_label: ""
    })

    add_site_config_type(%{
      key: "system.Login message",
      section: "System",
      type: "string",
      permissions: ["teiserver.admin"],
      description: "A message sent to all users when they login, leave empty for no message",
      default: "",
      value_label: ""
    })
  end

  defp system_configs() do
    add_site_config_type(%{
      key: "system.Redirect url",
      section: "System",
      type: "string",
      permissions: ["teiserver.admin"],
      description: "A redirect URL for those accessing the old server",
      value_label: "The URL for the redirect"
    })

    add_site_config_type(%{
      key: "system.Disconnect unauthenticated sockets",
      section: "System",
      type: "boolean",
      default: false,
      permissions: ["teiserver.admin"],
      description: "When enabled sockets not authenticated after 60 seconds will be disconnected",
      value_label: "Disconnect unauthenticated sockets"
    })

    add_site_config_type(%{
      key: "system.Process matches",
      section: "System",
      type: "boolean",
      permissions: ["teiserver.admin"],
      description: "Enable/disable post processing of matches",
      default: true,
      value_label: "Enable"
    })

    add_site_config_type(%{
      key: "system.Use geoip",
      section: "System",
      type: "boolean",
      permissions: ["teiserver.admin"],
      description: "When enabled you will use geoip for country code lookups",
      default: true,
      value_label: ""
    })
  end

  defp lobby_configs() do
    add_site_config_type(%{
      key: "teiserver.Uncertainty required to show rating",
      section: "Lobbies",
      type: "integer",
      permissions: ["teiserver.admin"],
      description: "The maximum value uncertainty can be before in-game rating is shown ",
      default: 10
    })

    add_site_config_type(%{
      key: "teiserver.Allow tournament command",
      section: "Lobbies",
      type: "boolean",
      permissions: ["teiserver.admin"],
      description:
        "When set to true, the $tournament command will be able to be used. When disabled it can still be used but only to turn off tournament mode.",
      default: false
    })

    add_site_config_type(%{
      key: "teiserver.Default player limit",
      section: "Lobbies",
      type: "integer",
      permissions: ["teiserver.admin"],
      description: "The default player limit for lobbies",
      default: 16
    })

    add_site_config_type(%{
      key: "teiserver.Max deviation",
      section: "Lobbies",
      type: "integer",
      permissions: ["teiserver.admin"],
      description:
        "The maximum deviation in mixed party-solo balance before it reverts to purely solo balance",
      default: 10
    })

    add_site_config_type(%{
      key: "teiserver.Enable server balance",
      section: "Lobbies",
      type: "boolean",
      permissions: ["teiserver.admin"],
      description: "Enable server-side balance for lobbies",
      default: true
    })

    add_site_config_type(%{
      key: "teiserver.Curse word score A",
      section: "Lobbies",
      type: "integer",
      permissions: ["teiserver.admin.account"],
      description: "Points for the harshest of curse words",
      default: 10
    })

    add_site_config_type(%{
      key: "teiserver.Curse word score B",
      section: "Lobbies",
      type: "integer",
      permissions: ["teiserver.admin.account"],
      description: "Points for the middlest of curse words",
      default: 4
    })

    add_site_config_type(%{
      key: "teiserver.Curse word score C",
      section: "Lobbies",
      type: "integer",
      permissions: ["teiserver.admin.account"],
      description: "Points for the lightest of curse words",
      default: 1
    })
  end

  defp discord_configs() do
    add_site_config_type(%{
      key: "teiserver.Bridge from discord",
      section: "Discord",
      type: "boolean",
      permissions: ["teiserver.staff.moderator"],
      description: "Enables bridging from discord to in-lobby channels",
      default: true
    })

    add_site_config_type(%{
      key: "teiserver.Bridge from server",
      section: "Discord",
      type: "boolean",
      permissions: ["teiserver.staff.moderator"],
      description: "Enables bridging from in-lobby channels to discord",
      default: true
    })

    add_site_config_type(%{
      key: "teiserver.Bridge player numbers",
      section: "Discord",
      type: "boolean",
      permissions: ["teiserver.admin"],
      description: "Enables bridging of channel names to discord",
      default: true
    })

    add_site_config_type(%{
      key: "teiserver.Discord channel #main",
      section: "Discord",
      type: "integer",
      permissions: ["teiserver.admin"],
      description: "The discord ID for the channel to bridge with #main"
    })

    add_site_config_type(%{
      key: "teiserver.Discord channel #newbies",
      section: "Discord",
      type: "integer",
      permissions: ["teiserver.admin"],
      description: "The discord ID for the channel to bridge with #newbies"
    })

    add_site_config_type(%{
      key: "teiserver.Discord channel #promote",
      section: "Discord",
      type: "integer",
      permissions: ["teiserver.admin"],
      description: "The discord ID for the channel to bridge for promoting games"
    })

    add_site_config_type(%{
      key: "teiserver.Discord channel #overwatch-reports",
      section: "Discord",
      type: "integer",
      permissions: ["teiserver.admin"],
      description: "The discord ID for the channel to post overwatch specific reports"
    })

    add_site_config_type(%{
      key: "teiserver.Discord channel #moderation-reports",
      section: "Discord",
      type: "integer",
      permissions: ["teiserver.admin"],
      description: "The discord ID for the channel to post moderation-reports"
    })

    add_site_config_type(%{
      key: "teiserver.Discord channel #moderation-actions",
      section: "Discord",
      type: "integer",
      permissions: ["teiserver.admin"],
      description: "The discord ID for the channel to post moderation-actions"
    })

    add_site_config_type(%{
      key: "teiserver.Discord channel #server-updates",
      section: "Discord",
      type: "integer",
      permissions: ["teiserver.admin"],
      description: "The discord ID for the channel to post server updates"
    })

    add_site_config_type(%{
      key: "teiserver.Discord channel #telemetry-infologs",
      section: "Discord",
      type: "integer",
      permissions: ["teiserver.admin"],
      description: "The discord ID for the channel to post infologs"
    })

    add_site_config_type(%{
      key: "teiserver.Discord forum #gdt-discussion",
      section: "Discord",
      type: "integer",
      permissions: ["teiserver.admin"],
      description: "The discord ID for the forum for starting GDT discussions"
    })

    add_site_config_type(%{
      key: "teiserver.Discord forum #gdt-voting",
      section: "Discord",
      type: "integer",
      permissions: ["teiserver.admin"],
      description: "The discord ID for the forum for starting GDT voting"
    })

    # User number channels
    add_site_config_type(%{
      key: "teiserver.Discord counter clients",
      section: "Discord",
      type: "integer",
      permissions: ["teiserver.admin"],
      description: "The discord ID for the channel broadcasting client count"
    })

    add_site_config_type(%{
      key: "teiserver.Discord counter players",
      section: "Discord",
      type: "integer",
      permissions: ["teiserver.admin"],
      description: "The discord ID for the channel broadcasting player count"
    })

    add_site_config_type(%{
      key: "teiserver.Discord counter matches",
      section: "Discord",
      type: "integer",
      permissions: ["teiserver.admin"],
      description: "The discord ID for the channel broadcasting match count"
    })

    add_site_config_type(%{
      key: "teiserver.Discord counter lobbies",
      section: "Discord",
      type: "integer",
      permissions: ["teiserver.admin"],
      description: "The discord ID for the channel broadcasting lobby count"
    })
  end

  @spec debugging_configs :: :ok
  def debugging_configs() do
    add_site_config_type(%{
      key: "debug.Print outgoing messages",
      section: "Debug",
      type: "boolean",
      default: false,
      permissions: ["teiserver.admin"],
      description: "Print all outgoing messages"
    })

    add_site_config_type(%{
      key: "debug.Print incoming messages",
      section: "Debug",
      type: "boolean",
      default: false,
      permissions: ["teiserver.admin"],
      description: "Print all incoming messages"
    })
  end
end
