defmodule Teiserver.TeiserverQuickActions do
  alias Central.General.QuickAction

  @spec teiserver_quick_actions :: any
  def teiserver_quick_actions do
    QuickAction.add_items([
      # Global page
      %{
        label: "Live lobbies",
        icons: [Teiserver.Battle.LobbyLib.icon()],
        url: "/teiserver/battle/lobbies",
        permissions: "teiserver"
      },

      # Profile/Account
      %{
        label: "My profile",
        icons: ["fa-solid fa-user-circle"],
        url: "/teiserver/profile",
        permissions: "teiserver"
      },
      %{
        label: "Friends/Mutes/Invites",
        icons: [Teiserver.icon(:relationship)],
        url: "/teiserver/account/relationships",
        permissions: "teiserver"
      },
      %{
        label: "Profile appearance",
        icons: ["fa-solid fa-icons"],
        url: "/teiserver/account/customisation_form",
        permissions: "teiserver"
      },
      %{
        label: "Teiserver preferences",
        icons: [Central.Config.UserConfigLib.icon()],
        url: "/teiserver/account/preferences",
        permissions: "teiserver"
      },

      # Your stuff but not part of profile/account
      %{
        label: "My match history",
        icons: [Teiserver.Battle.LobbyLib.icon(), :list],
        url: "/teiserver/battle/matches",
        permissions: "teiserver"
      },
      %{
        label: "Matchmaking",
        icons: [Teiserver.Game.QueueLib.icon()],
        url: "/teiserver/games/queues",
        permissions: "teiserver.player.verified"
      },

      # Moderator pages
      %{
        label: "Live clients",
        icons: [Teiserver.Account.ClientLib.icon(), :list],
        url: "/teiserver/admin/client",
        permissions: "teiserver.moderator.account"
      },
      %{
        label: "Teiserver users",
        icons: [Teiserver.Account.ClientLib.icon(), :list],
        input: "s",
        method: "get",
        placeholder: "Search username",
        url: "/teiserver/admin/users/search",
        permissions: "teiserver.moderator.account"
      },
      %{
        label: "Chat logs",
        icons: [Central.Communication.CommentLib.icon(), :list],
        url: "/teiserver/admin/chat",
        permissions: "teiserver.moderator.account"
      },
      # %{
      #   label: "Clan admin",
      #   icons: [Teiserver.Clans.ClanLib.icon(), :list],
      #   url: "/teiserver/admin/clans",
      #   permissions: "teiserver.moderator"
      # },

      # Admin pages
      %{
        label: "Teiserver dashboard",
        icons: ["fa-regular fa-tachometer-alt", :list],
        url: "/logging/live/dashboard/metrics?nav=teiserver",
        permissions: "logging.live.show"
      },
      %{
        label: "Client events",
        icons: ["fa-regular #{Teiserver.Telemetry.ClientEventLib.icon()}", :list],
        url: "/teiserver/reports/client_events/summary",
        permissions: "teiserver.admin"
      },
      %{
        label: "Infologs",
        icons: ["fa-regular #{Teiserver.Telemetry.InfologLib.icon()}", :list],
        url: "/teiserver/reports/client_events/summary",
        permissions: "teiserver.moderator.telemetry"
      },
      %{
        label: "Match list",
        icons: [Teiserver.Battle.MatchLib.icon(), :list],
        url: "/teiserver/admin/matches?search=true",
        permissions: "teiserver.moderator"
      },

      # Specific report
      %{
        label: "Active",
        icons: ["fa-regular #{Teiserver.Account.ActiveReport.icon()}"],
        permissions: "teiserver.moderator",
        url: "/teiserver/reports/show/active"
      },
      %{
        label: "Time spent",
        icons: ["fa-regular #{Teiserver.Account.TimeSpentReport.icon()}"],
        permissions: "teiserver.moderator",
        url: "/teiserver/reports/show/time_spent"
      },
      %{
        label: "Ranks",
        icons: ["fa-regular #{Teiserver.Account.RanksReport.icon()}"],
        permissions: "teiserver.moderator",
        url: "/teiserver/reports/show/ranks"
      },
      %{
        label: "Verified",
        icons: ["fa-regular #{Teiserver.Account.VerifiedReport.icon()}"],
        permissions: "teiserver.moderator",
        url: "/teiserver/reports/show/verified"
      },
      %{
        label: "Retention",
        icons: ["fa-regular #{Teiserver.Account.RetentionReport.icon()}"],
        permissions: "teiserver.moderator",
        url: "/teiserver/reports/show/retention"
      },
      %{
        label: "New user funnel",
        icons: ["fa-regular #{Teiserver.Account.NewUserFunnelReport.icon()}"],
        permissions: "teiserver.moderator",
        url: "/teiserver/reports/show/new_user_funnel"
      },
      %{
        label: "Accolades",
        icons: ["fa-regular #{Teiserver.Account.AccoladeLib.icon()}"],
        permissions: "teiserver.moderator",
        url: "/teiserver/reports/show/accolades"
      },
      %{
        label: "Mutes",
        icons: ["fa-regular #{Teiserver.Account.MuteReport.icon()}"],
        permissions: "teiserver.moderator",
        url: "/teiserver/reports/show/mutes"
      },
      %{
        label: "Review",
        icons: ["fa-regular #{Teiserver.Account.ReviewReport.icon()}"],
        permissions: "teiserver.moderator",
        url: "/teiserver/reports/show/review"
      },

      %{
        label: "Teiserver infologs",
        icons: ["fa-regular #{Teiserver.Telemetry.InfologLib.icon()}", :list],
        url: "/teiserver/reports/infolog",
        permissions: "teiserver.moderator.telemetry"
      },

      # Server metrics
      %{
        label: "Server metrics - Daily",
        icons: ["fa-regular #{Teiserver.Telemetry.ServerDayLogLib.icon()}", :day],
        url: "/teiserver/reports/server/day_metrics",
        permissions: "teiserver.moderator"
      },
      %{
        label: "Server metrics - Monthly",
        icons: ["fa-regular #{Teiserver.Telemetry.ServerDayLogLib.icon()}", :month],
        url: "/teiserver/reports/server/month_metrics",
        permissions: "teiserver.moderator"
      },
      %{
        label: "Server metrics - Now report",
        icons: ["fa-regular #{Teiserver.Telemetry.ServerDayLogLib.icon()}", "fa-regular fa-clock"],
        url: "/teiserver/reports/server/day_metrics/now",
        permissions: "teiserver.moderator"
      },
      %{
        label: "Server metrics - Load report",
        icons: ["fa-regular #{Teiserver.Telemetry.ServerDayLogLib.icon()}", "fa-regular fa-server"],
        url: "/teiserver/reports/server/day_metrics/load",
        permissions: "teiserver.moderator"
      },

      # Match metrics
      %{
        label: "Match metrics - Daily",
        icons: ["fa-regular #{Teiserver.Battle.MatchLib.icon()}", :day],
        url: "/teiserver/reports/match/day_metrics",
        permissions: "teiserver.moderator"
      },
      %{
        label: "Match metrics - Monthly",
        icons: ["fa-regular #{Teiserver.Battle.MatchLib.icon()}", :month],
        url: "/teiserver/reports/match/month_metrics",
        permissions: "teiserver.moderator"
      },

      # Dev/Admin
      %{
        label: "Teiserver live metrics",
        icons: ["fa-regular fa-tachometer-alt", :list],
        url: "/teiserver/admin/metrics",
        permissions: "logging.live"
      }
    ])
  end
end
