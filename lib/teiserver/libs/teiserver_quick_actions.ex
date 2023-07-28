defmodule Teiserver.TeiserverQuickActions do
  @moduledoc false

  use CentralWeb, :verified_routes
  alias Central.General.QuickAction

  @spec teiserver_quick_actions :: any
  def teiserver_quick_actions do
    items =
      [
        # Global page
        %{
          label: "Live lobbies",
          icons: [Teiserver.Lobby.icon()],
          url: ~p"/battle/lobbies",
          permissions: "account"
        },

        # Profile/Account
        %{
          label: "My profile",
          icons: ["fa-solid fa-user-circle"],
          url: ~p"/teiserver/profile",
          permissions: "account"
        },
        %{
          label: "Friends/Mutes/Invites",
          icons: [Teiserver.icon(:relationship)],
          url: ~p"/teiserver/account/relationships",
          permissions: "account"
        },
        %{
          label: "Profile appearance",
          icons: ["fa-solid fa-icons"],
          url: ~p"/teiserver/account/customisation_form",
          permissions: "account"
        },
        %{
          label: "Teiserver preferences",
          icons: [Teiserver.Config.UserConfigLib.icon()],
          url: ~p"/teiserver/account/preferences",
          permissions: "account"
        },

        # Your stuff but not part of profile/account
        %{
          label: "Matchmaking",
          icons: [Teiserver.Game.QueueLib.icon()],
          url: ~p"/teiserver/games/queues"
        },

        # Moderator pages
        %{
          label: "Live clients",
          icons: [Teiserver.Account.ClientLib.icon(), :list],
          url: ~p"/teiserver/admin/client",
          permissions: "Moderator"
        },
        %{
          label: "Teiserver users",
          icons: [Teiserver.Account.ClientLib.icon(), :list],
          input: "s",
          method: "get",
          placeholder: "Search username",
          url: ~p"/teiserver/admin/users/search",
          permissions: "Moderator"
        },
        %{
          label: "Chat logs",
          icons: [Teiserver.Chat.LobbyMessageLib.icon(), :list],
          url: ~p"/teiserver/admin/chat",
          permissions: "Moderator"
        },

        # Logging
        # Match metrics
        %{
          label: "Match metrics - Daily",
          icons: ["fa-regular #{Teiserver.Battle.MatchLib.icon()}", :day],
          url: ~p"/logging/match/day_metrics",
          permissions: "Moderator"
        },
        %{
          label: "Match metrics - Monthly",
          icons: ["fa-regular #{Teiserver.Battle.MatchLib.icon()}", :month],
          url: ~p"/logging/match/month_metrics",
          permissions: "Moderator"
        },

        # Server metrics
        %{
          label: "Server metrics - Daily",
          icons: ["fa-regular #{Teiserver.Logging.ServerDayLogLib.icon()}", :day],
          url: ~p"/logging/server/list",
          permissions: "Moderator"
        },
        %{
          label: "Server metrics - Now report",
          icons: ["fa-regular #{Teiserver.Logging.ServerDayLogLib.icon()}", "fa-regular fa-clock"],
          url: ~p"/logging/server/now",
          permissions: "Moderator"
        },
        %{
          label: "Server metrics - Load report",
          icons: [
            "fa-regular #{Teiserver.Logging.ServerDayLogLib.icon()}",
            "fa-regular fa-server"
          ],
          url: ~p"/logging/server/load",
          permissions: "Moderator"
        },

        # Admin pages
        %{
          label: "Teiserver dashboard",
          icons: ["fa-regular fa-tachometer-alt", :list],
          url: ~p"/logging/live/dashboard/metrics?nav=teiserver",
          permissions: "logging.live.show"
        },
        %{
          label: "Properties telemetry",
          icons: ["fa-regular #{Teiserver.Telemetry.PropertyTypeLib.icon()}", :list],
          url: ~p"/telemetry/properties/summary",
          permissions: "Admin"
        },
        %{
          label: "Client event telemetry",
          icons: ["fa-regular #{Teiserver.Telemetry.ClientEventLib.icon()}", :list],
          url: ~p"/telemetry/client_events/summary",
          permissions: "Admin"
        },
        %{
          label: "Infologs",
          icons: ["fa-regular #{Teiserver.Telemetry.InfologLib.icon()}", :list],
          url: ~p"/teiserver/reports/infolog",
          permissions: "Server"
        },
        %{
          label: "Match list",
          icons: [Teiserver.Battle.MatchLib.icon(), :list],
          url: ~p"/teiserver/admin/matches?search=true",
          permissions: "Moderator"
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
      # Other
      %{
        label: "Teiserver infologs",
        icons: ["fa-regular #{Teiserver.Telemetry.InfologLib.icon()}", :list],
        url: ~p"/teiserver/reports/infolog",
        permissions: "Server"
      }
    ]
  end

  defp specific_report_actions() do
    [
      %{
        label: "Active",
        icons: ["fa-regular #{Teiserver.Account.ActiveReport.icon()}"],
        permissions: "Moderator",
        url: ~p"/teiserver/reports/show/active"
      },
      %{
        label: "Time spent",
        icons: ["fa-regular #{Teiserver.Account.TimeSpentReport.icon()}"],
        permissions: "Moderator",
        url: ~p"/teiserver/reports/show/time_spent"
      },
      %{
        label: "User age",
        icons: ["fa-regular #{Teiserver.Account.UserAgeReport.icon()}"],
        permissions: "Moderator",
        url: ~p"/teiserver/reports/show/user_age"
      },
      %{
        label: "Verified",
        icons: ["fa-regular #{Teiserver.Account.VerifiedReport.icon()}"],
        permissions: "Moderator",
        url: ~p"/teiserver/reports/show/verified"
      },
      %{
        label: "Retention",
        icons: ["fa-regular #{Teiserver.Account.RetentionReport.icon()}"],
        permissions: "Moderator",
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
        permissions: "Moderator",
        url: ~p"/teiserver/reports/show/accolades"
      },
      %{
        label: "New smurfs",
        icons: ["fa-regular #{Teiserver.Account.NewSmurfReport.icon()}"],
        permissions: Teiserver.Account.NewSmurfReport.permissions(),
        url: ~p"/teiserver/reports/show/new_smurf"
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
        label: "Week on week",
        icons: ["fa-regular #{Teiserver.Account.WeekOnWeekReport.icon()}"],
        permissions: Teiserver.Account.WeekOnWeekReport.permissions(),
        url: ~p"/teiserver/reports/show/week_on_week"
      },
      %{
        label: "Moderation activity",
        icons: ["fa-regular #{Teiserver.Moderation.ActivityReport.icon()}"],
        permissions: Teiserver.Moderation.ActivityReport.permissions(),
        url: ~p"/teiserver/reports/show/moderation_activity"
      }
    ]
  end

  defp moderation_actions() do
    [
      %{
        label: "Moderation reports",
        icons: [Teiserver.Moderation.ReportLib.icon(), :list],
        url: ~p"/moderation/report",
        permissions: "Reviewer"
      },
      %{
        label: "Moderation actions",
        icons: [Teiserver.Moderation.ActionLib.icon(), :list],
        url: ~p"/moderation/action",
        permissions: "Reviewer"
      },
      %{
        label: "Moderation proposals",
        icons: [Teiserver.Moderation.ProposalLib.icon(), :list],
        url: ~p"/moderation/proposal",
        permissions: "Reviewer"
      },
      %{
        label: "Moderation bans",
        icons: [Teiserver.Moderation.BanLib.icon(), :list],
        url: ~p"/moderation/ban",
        permissions: "Reviewer"
      }
    ]
  end
end
