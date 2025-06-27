defmodule Teiserver.TeiserverConfigs do
  @moduledoc false
  import Teiserver.Config, only: [add_site_config_type: 1]

  @spec teiserver_configs :: any
  def teiserver_configs do
    # Site based configs
    site_configs()
    login_configs()
    legacy_protocol_configs()
    moderation_configs()
    discord_configs()
    lobby_configs()
    debugging_configs()
    profile_configs()
    rating_configs()
    tachyon_configs()
    :ok
  end

  @spec site_configs :: any
  defp site_configs do
    add_site_config_type(%{
      key: "site.Footer credit text",
      section: "Site",
      type: "string",
      permissions: ["Server"],
      description: "The text shown at the bottom of the page.",
      default: "Created by the Beyond all Reason team"
    })

    add_site_config_type(%{
      key: "matchmaking.Use ready check",
      section: "Matchmaking",
      type: "boolean",
      permissions: ["Server"],
      description: "When set to true matchmaking uses a ready check",
      default: true,
      value_label: "Require ready check"
    })

    add_site_config_type(%{
      key: "matchmaking.Time to treat game as ranked",
      section: "Matchmaking",
      type: "integer",
      permissions: ["Server"],
      description: "Games shorter than this time in seconds will not be treated as ranked.",
      default: 90,
      value_label: "Require ready check"
    })

    add_site_config_type(%{
      key: "bots.Flag",
      section: "Bots",
      type: "string",
      permissions: ["Server"],
      description: "Country code flag used by bots managed by the server",
      default: "GB",
      value_label: ""
    })

    add_site_config_type(%{
      key: "teiserver.Enable accolades",
      section: "Accolades",
      type: "boolean",
      permissions: ["Server"],
      description:
        "When enabled, players will be offered the chance to bestow accolades to each other.",
      default: true
    })

    add_site_config_type(%{
      key: "teiserver.Inform of new accolades",
      section: "Accolades",
      type: "boolean",
      permissions: ["Server"],
      description: "When set to true, players will be informed when they get a new accolade",
      default: false
    })

    add_site_config_type(%{
      key: "teiserver.Accolade gift limit",
      section: "Accolades",
      type: "integer",
      permissions: ["Server"],
      description: "The number of accolades you can gift within the allocated window.",
      default: 20
    })

    add_site_config_type(%{
      key: "teiserver.Accolade gift window",
      section: "Accolades",
      type: "integer",
      permissions: ["Server"],
      description: "The window in days when checking the accolade gift limit.",
      default: 30
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
      permissions: ["Admin"],
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

    add_site_config_type(%{
      key: "site.Main site link",
      section: "Site management",
      type: "string",
      permissions: ["Admin"],
      description: "A link to an external site if this is not your main site.",
      opts: [],
      default: "",
      value_label: "Link"
    })
  end

  defp moderation_configs() do
    add_site_config_type(%{
      key: "teiserver.Warning acknowledge prompt",
      section: "Moderation",
      type: "string",
      permissions: ["Server"],
      description: "The string used to request acknowledgement of warnings",
      default: "Acknowledge this by typing 'I acknowledge this' to resume play"
    })

    add_site_config_type(%{
      key: "teiserver.Warning acknowledge response",
      section: "Moderation",
      type: "string",
      permissions: ["Server"],
      description: "The response string expected to acknowledge the warning",
      default: "I acknowledge this"
    })

    add_site_config_type(%{
      key: "teiserver.Automod action delay",
      section: "Moderation",
      type: "integer",
      permissions: ["Admin"],
      description: "The delay in seconds after a user logs in for the automod to check on them.",
      default: 120
    })

    add_site_config_type(%{
      key: "teiserver.Require HW data to play",
      section: "Moderation",
      type: "boolean",
      permissions: ["Admin"],
      description: "Prevents someone from being a player if they don't have a HW hash yet.",
      default: false
    })

    add_site_config_type(%{
      key: "teiserver.Require Chobby data to play",
      section: "Moderation",
      type: "boolean",
      permissions: ["Admin"],
      description: "Prevents someone from being a player if they don't have a Chobby key yet.",
      default: false
    })
  end

  defp legacy_protocol_configs() do
    add_site_config_type(%{
      key: "teiserver.Spring flood rate limit count",
      section: "Legacy protocol",
      type: "integer",
      permissions: ["Admin"],
      description: "The number of commands required to trip flood protection for Spring",
      default: 20
    })

    add_site_config_type(%{
      key: "teiserver.Spring flood rate window size",
      section: "Legacy protocol",
      type: "integer",
      permissions: ["Admin"],
      description: "The size of the window in seconds for flood protection to trip for Spring",
      default: 6
    })

    add_site_config_type(%{
      key: "teiserver.Ring flood rate limit count",
      section: "Legacy protocol",
      type: "integer",
      permissions: ["Admin"],
      description: "The number of rings required to trip flood protection",
      default: 5
    })

    add_site_config_type(%{
      key: "teiserver.Ring flood rate window size",
      section: "Legacy protocol",
      type: "integer",
      permissions: ["Admin"],
      description: "The size of the window in seconds for flood protection to trip for rings",
      default: 10
    })

    add_site_config_type(%{
      key: "teiserver.Post login action delay",
      section: "Legacy protocol",
      type: "integer",
      permissions: ["Admin"],
      description:
        "The time in milliseconds to wait until doing something when a user logs in (e.g. sending a message)",
      default: 2500
    })

    add_site_config_type(%{
      key: "teiserver.Sprint TCP Server max heap size",
      section: "Legacy protocol",
      type: "integer",
      permissions: ["Server"],
      description:
        "Max heap size in words for the TCP server used by the legacy protocol. Default is 13_107_200 words or 100 MB = 100 * 1024 * 1024 / 8 words = 13_107_200 words (1 word = 8 bytes)",
      default: 13_107_200
    })
  end

  defp login_configs() do
    add_site_config_type(%{
      key: "system.Login limit count",
      section: "Login",
      type: "integer",
      default: 3,
      permissions: ["Admin"],
      description: "How many times a user can attempt to login within the refresh window",
      value_label: "Login limit count"
    })

    add_site_config_type(%{
      key: "system.Post login delay",
      section: "Login",
      type: "integer",
      default: 1000,
      permissions: ["Admin"],
      description: "The duration (ms) to pause the process after logging in",
      value_label: "Post login delay (ms)"
    })

    add_site_config_type(%{
      key: "system.Use login throttle",
      section: "Login",
      type: "boolean",
      default: false,
      permissions: ["Admin"],
      description: "When enabled all login attempts will pass through the login throttle server",
      value_label: "Use login throttle"
    })

    add_site_config_type(%{
      key: "system.User limit",
      section: "Login",
      type: "integer",
      permissions: ["Admin"],
      description: "The cap for number of concurrent users, set to 0 to be infinite",
      default: 1000,
      value_label: ""
    })

    add_site_config_type(%{
      key: "system.Login message",
      section: "Login",
      type: "string",
      permissions: ["Admin"],
      description: "A message sent to all users when they login, leave empty for no message",
      default: "",
      value_label: ""
    })
  end

  defp lobby_configs() do
    add_site_config_type(%{
      key: "teiserver.Uncertainty required to show rating",
      section: "Lobbies",
      type: "integer",
      permissions: ["Admin"],
      description: "The maximum value uncertainty can be before in-game rating is shown ",
      default: 10
    })

    add_site_config_type(%{
      key: "teiserver.Allow tournament command",
      section: "Lobbies",
      type: "boolean",
      permissions: ["Admin"],
      description:
        "When set to true, the $tournament command will be able to be used. When disabled it can still be used but only to turn off tournament mode.",
      default: false
    })

    add_site_config_type(%{
      key: "teiserver.Default player limit",
      section: "Lobbies",
      type: "integer",
      permissions: ["Admin"],
      description: "The default player limit for lobbies",
      default: 16
    })

    add_site_config_type(%{
      key: "teiserver.Max deviation",
      section: "Lobbies",
      type: "integer",
      permissions: ["Admin"],
      description:
        "The maximum deviation in mixed party-solo balance before it reverts to purely solo balance",
      default: 10
    })

    add_site_config_type(%{
      key: "teiserver.Enable server balance",
      section: "Lobbies",
      type: "boolean",
      permissions: ["Admin"],
      description: "Enable server-side balance for lobbies",
      default: true
    })

    add_site_config_type(%{
      key: "teiserver.Default balance algorithm",
      section: "Lobbies",
      type: "select",
      default: "loser_picks",
      permissions: ["Admin"],
      description: "The default balance algorithm",
      opts: [choices: ["loser_picks", "auto"]]
    })

    add_site_config_type(%{
      key: "teiserver.Curse word score A",
      section: "Lobbies",
      type: "integer",
      permissions: ["Server"],
      description: "Points for the harshest of curse words",
      default: 10
    })

    add_site_config_type(%{
      key: "teiserver.Curse word score B",
      section: "Lobbies",
      type: "integer",
      permissions: ["Server"],
      description: "Points for the middlest of curse words",
      default: 4
    })

    add_site_config_type(%{
      key: "teiserver.Curse word score C",
      section: "Lobbies",
      type: "integer",
      permissions: ["Server"],
      description: "Points for the lightest of curse words",
      default: 1
    })

    add_site_config_type(%{
      key: "lobby.Block count to prevent join",
      section: "Lobbies",
      type: "integer",
      permissions: ["Admin"],
      description:
        "The raw number of users who would need to block someone to prevent them joining a lobby",
      default: 8
    })

    add_site_config_type(%{
      key: "lobby.Block percentage to prevent join",
      section: "Lobbies",
      type: "integer",
      permissions: ["Admin"],
      description:
        "The percentage of users who would need to block someone to prevent them joining a lobby",
      default: 50
    })

    add_site_config_type(%{
      key: "lobby.Avoid min hours required",
      section: "Lobbies",
      type: "integer",
      permissions: ["Admin"],
      description: "Avoids must be at least this old to be considered",
      default: 2
    })

    add_site_config_type(%{
      key: "lobby.Small team game limit",
      section: "Lobbies",
      type: "integer",
      permissions: ["Admin"],
      description: "Maximum team size to be considered as a small team game",
      default: 5
    })
  end

  defp discord_configs() do
    add_site_config_type(%{
      key: "teiserver.Bridge from discord",
      section: "Discord",
      type: "boolean",
      permissions: ["Moderator"],
      description: "Enables bridging from discord to in-lobby channels",
      default: true
    })

    add_site_config_type(%{
      key: "teiserver.Bridge from server",
      section: "Discord",
      type: "boolean",
      permissions: ["Moderator"],
      description: "Enables bridging from in-lobby channels to discord",
      default: true
    })

    add_site_config_type(%{
      key: "teiserver.Bridge player numbers",
      section: "Discord",
      type: "boolean",
      permissions: ["Admin"],
      description: "Enables bridging of channel names to discord",
      default: true
    })

    add_site_config_type(%{
      key: "teiserver.Discord channel #main",
      section: "Discord",
      type: "integer",
      permissions: ["Admin"],
      description: "The discord ID for the channel to bridge with #main"
    })

    add_site_config_type(%{
      key: "teiserver.Discord channel #newbies",
      section: "Discord",
      type: "integer",
      permissions: ["Admin"],
      description: "The discord ID for the channel to bridge with #newbies"
    })

    add_site_config_type(%{
      key: "teiserver.Discord channel #promote",
      section: "Discord",
      type: "integer",
      permissions: ["Admin"],
      description: "The discord ID for the channel to bridge for promoting games"
    })

    add_site_config_type(%{
      key: "teiserver.Discord channel #overwatch-reports",
      section: "Discord",
      type: "integer",
      permissions: ["Admin"],
      description: "The discord ID for the channel to post overwatch specific reports"
    })

    add_site_config_type(%{
      key: "teiserver.Discord channel #moderation-reports",
      section: "Discord",
      type: "integer",
      permissions: ["Admin"],
      description: "The discord ID for the channel to post moderation-reports"
    })

    add_site_config_type(%{
      key: "teiserver.Discord channel #moderation-actions",
      section: "Discord",
      type: "integer",
      permissions: ["Admin"],
      description: "The discord ID for the channel to post moderation-actions"
    })

    add_site_config_type(%{
      key: "teiserver.Discord channel #server-updates",
      section: "Discord",
      type: "integer",
      permissions: ["Admin"],
      description: "The discord ID for the channel to post server updates"
    })

    add_site_config_type(%{
      key: "teiserver.Discord channel #telemetry-infologs",
      section: "Discord",
      type: "integer",
      permissions: ["Admin"],
      description: "The discord ID for the channel to post infologs"
    })

    add_site_config_type(%{
      key: "teiserver.Discord forum #gdt-discussion",
      section: "Discord",
      type: "integer",
      permissions: ["Admin"],
      description: "The discord ID for the forum for starting GDT discussions"
    })

    add_site_config_type(%{
      key: "teiserver.Discord forum #gdt-voting",
      section: "Discord",
      type: "integer",
      permissions: ["Admin"],
      description: "The discord ID for the forum for starting GDT voting"
    })

    # User number channels
    add_site_config_type(%{
      key: "teiserver.Discord counter clients",
      section: "Discord",
      type: "integer",
      permissions: ["Admin"],
      description: "The discord ID for the channel broadcasting client count"
    })

    add_site_config_type(%{
      key: "teiserver.Discord counter players",
      section: "Discord",
      type: "integer",
      permissions: ["Admin"],
      description: "The discord ID for the channel broadcasting player count"
    })

    add_site_config_type(%{
      key: "teiserver.Discord counter matches",
      section: "Discord",
      type: "integer",
      permissions: ["Admin"],
      description: "The discord ID for the channel broadcasting match count"
    })

    add_site_config_type(%{
      key: "teiserver.Discord counter lobbies",
      section: "Discord",
      type: "integer",
      permissions: ["Admin"],
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
      permissions: ["Admin"],
      description: "Print all outgoing messages"
    })

    add_site_config_type(%{
      key: "debug.Print incoming messages",
      section: "Debug",
      type: "boolean",
      default: false,
      permissions: ["Admin"],
      description: "Print all incoming messages"
    })
  end

  @spec profile_configs() :: :ok
  def profile_configs() do
    add_site_config_type(%{
      key: "profile.Rank method",
      section: "Profiles",
      type: "select",
      default: "Role",
      permissions: ["Admin"],
      description: "The value used to assign rank icons at login",
      opts: [choices: ["Leaderboard rating", "Rating value", "Playtime", "Role"]]
    })

    add_site_config_type(%{
      key: "user.Enable one time links",
      section: "User permissions",
      type: "boolean",
      permissions: ["Admin"],
      description: "Allows users to login with one-time-links.",
      opts: [],
      default: false,
      value_label: "Allow users to login via a one time link generated by the application."
    })

    add_site_config_type(%{
      key: "user.Enable renames",
      section: "User permissions",
      type: "boolean",
      permissions: ["Admin"],
      description: "Users are able to change their name via the account page.",
      opts: [],
      default: true,
      value_label: "Allow users to change their name"
    })

    add_site_config_type(%{
      key: "user.Enable account group pages",
      section: "User permissions",
      type: "boolean",
      permissions: ["Admin"],
      description: "Users are able to view (and edit) their group memberships.",
      opts: [],
      default: true,
      value_label: "Enable account group pages"
    })

    add_site_config_type(%{
      key: "user.Enable user registrations",
      section: "User permissions",
      type: "select",
      permissions: ["Admin"],
      description: "Users are able to view (and edit) their group memberships.",
      opts: [choices: ["Allowed", "Link only", "Disabled"]],
      default: "Allowed",
      value_label: "Enable account group pages"
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
  end

  defp rating_configs do
    add_site_config_type(%{
      key: "rating.Tau",
      section: "Rating",
      type: "float",
      permissions: ["Admin"],
      description: "Tau used by openskill lib",
      default: 1 / 3
    })

    add_site_config_type(%{
      key: "rating.Season",
      section: "Rating",
      type: "integer",
      permissions: ["Admin"],
      description: "Active season",
      default: 1
    })
  end

  defp tachyon_configs do
    Teiserver.Party.setup_site_configs()
    :ok
  end
end
