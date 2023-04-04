defmodule Teiserver.TeiserverQuickActions do
  use CentralWeb, :verified_routes
  alias Central.General.QuickAction

  @spec teiserver_quick_actions :: any
  def teiserver_quick_actions do
    items = [
      # Global page
      %{
        label: "Live lobbies",
        icons: [Teiserver.Battle.LobbyLib.icon()],
        url: ~p"/teiserver/battle/lobbies",
        permissions: "teiserver"
      },

      # Profile/Account
      %{
        label: "My profile",
        icons: ["fa-solid fa-user-circle"],
        url: ~p"/teiserver/profile",
        permissions: "teiserver"
      },
      %{
        label: "Friends/Mutes/Invites",
        icons: [Teiserver.icon(:relationship)],
        url: ~p"/teiserver/account/relationships",
        permissions: "teiserver"
      },
      %{
        label: "Profile appearance",
        icons: ["fa-solid fa-icons"],
        url: ~p"/teiserver/account/customisation_form",
        permissions: "teiserver"
      },
      %{
        label: "Teiserver preferences",
        icons: [Central.Config.UserConfigLib.icon()],
        url: ~p"/teiserver/account/preferences",
        permissions: "teiserver"
      },

      # Your stuff but not part of profile/account
      %{
        label: "My match history",
        icons: [Teiserver.Battle.LobbyLib.icon(), :list],
        url: ~p"/teiserver/battle/matches",
        permissions: "teiserver"
      },
      %{
        label: "Matchmaking",
        icons: [Teiserver.Game.QueueLib.icon()],
        url: ~p"/teiserver/games/queues",
        permissions: "teiserver.player.verified"
      },

      # Moderator pages
      %{
        label: "Live clients",
        icons: [Teiserver.Account.ClientLib.icon(), :list],
        url: ~p"/teiserver/admin/client",
        permissions: "teiserver.staff.moderator"
      },
      %{
        label: "Teiserver users",
        icons: [Teiserver.Account.ClientLib.icon(), :list],
        input: "s",
        method: "get",
        placeholder: "Search username",
        url: ~p"/teiserver/admin/users/search",
        permissions: "teiserver.staff.moderator"
      },
      %{
        label: "Chat logs",
        icons: [Central.Communication.CommentLib.icon(), :list],
        url: ~p"/teiserver/admin/chat",
        permissions: "teiserver.staff.moderator"
      },

      # Admin pages
      %{
        label: "Teiserver dashboard",
        icons: ["fa-regular fa-tachometer-alt", :list],
        url: ~p"/logging/live/dashboard/metrics?nav=teiserver",
        permissions: "logging.live.show"
      },
      %{
        label: "Client events",
        icons: ["fa-regular #{Teiserver.Telemetry.ClientEventLib.icon()}", :list],
        url: ~p"/teiserver/reports/client_events/summary",
        permissions: "teiserver.admin"
      },
      %{
        label: "Infologs",
        icons: ["fa-regular #{Teiserver.Telemetry.InfologLib.icon()}", :list],
        url: ~p"/teiserver/reports/client_events/summary",
        permissions: "teiserver.staff.telemetry"
      },
      %{
        label: "Match list",
        icons: [Teiserver.Battle.MatchLib.icon(), :list],
        url: ~p"/teiserver/admin/matches?search=true",
        permissions: "teiserver.staff.moderator"
      },

      # Dev/Admin
      %{
        label: "Teiserver live metrics",
        icons: ["fa-regular fa-tachometer-alt", :list],
        url: ~p"/teiserver/admin/metrics",
        permissions: "logging.live"
      }
    ] ++ moderation_actions() ++ report_actions() ++ specific_report_actions()

    QuickAction.add_items(items)
  end

  defp report_actions() do
    [
      # Match metrics
      %{
        label: "Match metrics - Daily",
        icons: ["fa-regular #{Teiserver.Battle.MatchLib.icon()}", :day],
        url: ~p"/teiserver/reports/match/day_metrics",
        permissions: "teiserver.staff.moderator"
      },
      %{
        label: "Match metrics - Monthly",
        icons: ["fa-regular #{Teiserver.Battle.MatchLib.icon()}", :month],
        url: ~p"/teiserver/reports/match/month_metrics",
        permissions: "teiserver.staff.moderator"
      },

      # Server metrics
      %{
        label: "Server metrics - Daily",
        icons: ["fa-regular #{Teiserver.Telemetry.ServerDayLogLib.icon()}", :day],
        url: ~p"/teiserver/reports/server/day_metrics",
        permissions: "teiserver.staff.moderator"
      },
      %{
        label: "Server metrics - Monthly",
        icons: ["fa-regular #{Teiserver.Telemetry.ServerDayLogLib.icon()}", :month],
        url: ~p"/teiserver/reports/server/month_metrics",
        permissions: "teiserver.staff.moderator"
      },
      %{
        label: "Server metrics - Now report",
        icons: ["fa-regular #{Teiserver.Telemetry.ServerDayLogLib.icon()}", "fa-regular fa-clock"],
        url: ~p"/teiserver/reports/server/day_metrics/now",
        permissions: "teiserver.staff.moderator"
      },
      %{
        label: "Server metrics - Load report",
        icons: [
          "fa-regular #{Teiserver.Telemetry.ServerDayLogLib.icon()}",
          "fa-regular fa-server"
        ],
        url: ~p"/teiserver/reports/server/day_metrics/load",
        permissions: "teiserver.staff.moderator"
      },

      # Other
      %{
        label: "Teiserver infologs",
        icons: ["fa-regular #{Teiserver.Telemetry.InfologLib.icon()}", :list],
        url: ~p"/teiserver/reports/infolog",
        permissions: "teiserver.staff.telemetry"
      },
    ]
  end

  defp specific_report_actions() do
    [
      %{
        label: "Active",
        icons: ["fa-regular #{Teiserver.Account.ActiveReport.icon()}"],
        permissions: "teiserver.staff.moderator",
        url: ~p"/teiserver/reports/show/active"
      },
      %{
        label: "Time spent",
        icons: ["fa-regular #{Teiserver.Account.TimeSpentReport.icon()}"],
        permissions: "teiserver.staff.moderator",
        url: ~p"/teiserver/reports/show/time_spent"
      },
      %{
        label: "Ranks",
        icons: ["fa-regular #{Teiserver.Account.RanksReport.icon()}"],
        permissions: "teiserver.staff.moderator",
        url: ~p"/teiserver/reports/show/ranks"
      },
      %{
        label: "Verified",
        icons: ["fa-regular #{Teiserver.Account.VerifiedReport.icon()}"],
        permissions: "teiserver.staff.moderator",
        url: ~p"/teiserver/reports/show/verified"
      },
      %{
        label: "Retention",
        icons: ["fa-regular #{Teiserver.Account.RetentionReport.icon()}"],
        permissions: "teiserver.staff.moderator",
        url: ~p"/teiserver/reports/show/retention"
      },
      %{
        label: "Population",
        icons: ["fa-regular #{Teiserver.Account.PopulationReport.icon()}"],
        permissions: Teiserver.Account.PopulationReport.permissions(),
        url: ~p"/teiserver/reports/show/population"
      },
      %{
        label: "New user funnel",
        icons: ["fa-regular #{Teiserver.Account.NewUserFunnelReport.icon()}"],
        permissions: Teiserver.Account.NewUserFunnelReport.permissions(),
        url: ~p"/teiserver/reports/show/new_user_funnel"
      },
      %{
        label: "Accolades",
        icons: ["fa-regular #{Teiserver.Account.AccoladeLib.icon()}"],
        permissions: "teiserver.staff.moderator",
        url: ~p"/teiserver/reports/show/accolades"
      },
      %{
        label: "Tournament",
        icons: ["fa-regular #{Teiserver.Account.TournamentReport.icon()}"],
        permissions: Teiserver.Account.TournamentReport.permissions(),
        url: ~p"/teiserver/reports/show/tournament"
      },
      %{
        label: "Mutes",
        icons: ["fa-regular #{Teiserver.Account.MuteReport.icon()}"],
        permissions: Teiserver.Account.MuteReport.permissions(),
        url: ~p"/teiserver/reports/show/mutes"
      },
      %{
        label: "Review",
        icons: ["fa-regular #{Teiserver.Account.ReviewReport.icon()}"],
        permissions: Teiserver.Account.ReviewReport.permissions(),
        url: ~p"/teiserver/reports/show/review"
      },
      %{
        label: "Growth",
        icons: ["fa-regular #{Teiserver.Account.GrowthReport.icon()}"],
        permissions: Teiserver.Account.GrowthReport.permissions(),
        url: ~p"/teiserver/reports/show/growth"
      },
      %{
        label: "Moderation activity",
        icons: ["fa-regular #{Teiserver.Moderation.ActivityReport.icon()}"],
        permissions: Teiserver.Moderation.ActivityReport.permissions(),
        url: ~p"/teiserver/reports/show/moderation_activity"
      },
    ]
  end

  defp moderation_actions() do
    [
      %{
        label: "Moderation reports",
        icons: [Teiserver.Moderation.ReportLib.icon(), :list],
        url: ~p"/moderation/report",
        permissions: "teiserver.staff.reviewer"
      },
      %{
        label: "Moderation actions",
        icons: [Teiserver.Moderation.ActionLib.icon(), :list],
        url: ~p"/moderation/action",
        permissions: "teiserver.staff.reviewer"
      },
      %{
        label: "Moderation proposals",
        icons: [Teiserver.Moderation.ProposalLib.icon(), :list],
        url: ~p"/moderation/proposal",
        permissions: "teiserver.staff.reviewer"
      },
      %{
        label: "Moderation bans",
        icons: [Teiserver.Moderation.BanLib.icon(), :list],
        url: ~p"/moderation/ban",
        permissions: "teiserver.staff.reviewer"
      }
    ]
  end
end
