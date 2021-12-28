defmodule Teiserver.Startup do
  use CentralWeb, :startup
  require Logger
  alias Teiserver.{Account, User}

  @spec startup :: :ok
  def startup do
    start_time = System.system_time(:millisecond)

    add_permission_set("teiserver", "admin", ~w(account battle clan queue))
    add_permission_set("teiserver", "moderator", ~w(account battle clan queue telemetry))
    add_permission_set("teiserver", "api", ~w(battle))
    add_permission_set("teiserver", "player", ~w(account tester contributor dev streamer donor verified bot moderator))

    add_group_type("Teiserver clan", %{fields: []})


    # Example site configs
    add_site_config_type(%{
      key: "teiserver.Require Chobby login",
      section: "Registrations",
      type: "boolean",
      permissions: ["admin.dev.developer"],
      description: "Prevents users registering with anything other than Chobby",
      opts: [],
      default: false
    })

    add_site_config_type(%{
      key: "teiserver.Bridge from discord",
      section: "Discord",
      type: "boolean",
      permissions: ["teiserver.moderator"],
      description: "Enables bridging from discord to in-lobby channels",
      opts: [],
      default: true
    })

    add_site_config_type(%{
      key: "teiserver.Bridge from server",
      section: "Discord",
      type: "boolean",
      permissions: ["teiserver.moderator"],
      description: "Enables bridging from in-lobby channels to discord",
      opts: [],
      default: true
    })

    umbrella_group =
      case Central.Account.get_group(nil, search: [name: "Teiserver umbrella group"]) do
        nil ->
          {:ok, group} =
            Central.Account.create_group(%{
              "name" => "Teiserver umbrella group",
              "active" => true,
              "icon" => "fa-duotone fa-umbrella",
              "colour" => "#00AA66",
              "data" => %{}
            })

          group

        group ->
          group
      end

    player_group =
      case Central.Account.get_group(nil, search: [name: "Teiserver Users"]) do
        nil ->
          {:ok, group} =
            Central.Account.create_group(%{
              "name" => "Teiserver Users",
              "active" => true,
              "icon" => "fa-duotone fa-robot",
              "colour" => "#00AA00",
              "data" => %{},
              "super_group_id" => umbrella_group.id
            })

          group

        group ->
          group
      end

    internal_group =
      case Central.Account.get_group(nil, search: [name: "Teiserver Internal Processes"]) do
        nil ->
          {:ok, group} =
            Central.Account.create_group(%{
              "name" => "Teiserver Internal Processes",
              "active" => true,
              "icon" => "fa-duotone fa-microchip",
              "colour" => "#660066",
              "data" => %{},
              "super_group_id" => umbrella_group.id
            })

          group

        group ->
          group
      end

    ConCache.put(:application_metadata_cache, "teiserver_umbrella_group", umbrella_group.id)
    ConCache.put(:application_metadata_cache, "teiserver_user_group", player_group.id)
    ConCache.put(:application_metadata_cache, "teiserver_internal_group", internal_group.id)

    Central.Account.GroupCacheLib.update_caches(player_group)
    Central.Account.GroupCacheLib.update_caches(internal_group)
    Central.Account.GroupCacheLib.update_caches(umbrella_group)

    # Quick actions
    QuickAction.add_items([
      # General pages
      %{
        label: "Friends/Mutes/Invites",
        icons: [Teiserver.icon(:relationship), :list],
        url: "/teiserver/account/relationships",
        permissions: "teiserver"
      },
      %{
        label: "Teiserver live metrics",
        icons: ["far fa-tachometer-alt", :list],
        url: "/teiserver/admin/metrics",
        permissions: "logging.live"
      },
      %{
        label: "Clans",
        icons: [Teiserver.Clans.ClanLib.icon(), :list],
        url: "/teiserver/account/clans",
        permissions: "teiserver"
      },
      %{
        label: "Battles",
        icons: [Teiserver.Battle.LobbyLib.icon(), :list],
        url: "/teiserver/battle/lobbies",
        permissions: "teiserver"
      },

      # Mod pages
      %{
        label: "Clients",
        icons: [Teiserver.ClientLib.icon(), :list],
        url: "/teiserver/admin/client",
        permissions: "teiserver.moderator"
      },
      %{
        label: "Live queues",
        icons: [Teiserver.Game.QueueLib.icon(), :list],
        url: "/teiserver/admin_live/queues",
        permissions: "teiserver.moderator"
      },
      %{
        label: "Teiserver users",
        icons: [Teiserver.ClientLib.icon(), :list],
        input: "s",
        method: "get",
        placeholder: "Search username",
        url: "/teiserver/admin/users/search",
        permissions: "teiserver.moderator"
      },

      # %{label: "Parties", icons: [Teiserver.ClientLib.icon(), :list], url: "/teiserver/admin/parties", permissions: "teiserver.moderator"},
      %{
        label: "Clan admin",
        icons: [Teiserver.Clans.ClanLib.icon(), :list],
        url: "/teiserver/admin/clans",
        permissions: "teiserver.moderator"
      },

      # Admin pages
      %{
        label: "Teiserver dashboard",
        icons: ["fa-regular fa-tachometer-alt", :list],
        url: "/logging/live/dashboard/metrics?nav=teiserver",
        permissions: "logging.live.show"
      },
      %{
        label: "Teiserver client events",
        icons: ["fa-regular #{Teiserver.Telemetry.ClientEventLib.icon()}", :list],
        url: "/teiserver/reports/client_events/summary",
        permissions: "teiserver.admin"
      },
      %{
        label: "Teiserver server metrics",
        icons: ["fa-regular #{Teiserver.Telemetry.ServerDayLogLib.icon()}", :list],
        url: "/teiserver/reports/client_events/summary",
        permissions: "teiserver.admin"
      },
      %{
        label: "Teiserver match metrics",
        icons: ["fa-regular #{Teiserver.Battle.MatchLib.icon()}", :list],
        url: "/teiserver/reports/client_events/summary",
        permissions: "teiserver.admin"
      },
      %{
        label: "Teiserver infologs",
        icons: ["fa-regular #{Teiserver.Telemetry.InfologLib.icon()}", :list],
        url: "/teiserver/reports/client_events/summary",
        permissions: "teiserver.moderator.telemetry"
      },
      %{
        label: "Teiserver reports",
        icons: ["fa-regular #{Central.Helpers.StylingHelper.icon(:report)}", :list],
        url: "/teiserver/reports/client_events/summary",
        permissions: "teiserver.admin"
      }
    ])

    # User configs
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

    ConCache.put(:lists, :clients, [])
    ConCache.put(:lists, :rooms, [])
    ConCache.insert_new(:lists, :lobbies, [])

    # We tried having a random lobby id start number to help prevent people joining
    # ongoing games but it didn't work
    # # We were using :rand.uniform() but it wasn't being random
    # # since we don't care about random random we're okay with this!
    # bid = :erlang.system_time()
    #   |> to_string
    #   |> String.reverse()
    #   |> String.slice(0..5)
    #   |> String.to_integer()
    ConCache.put(:id_counters, :battle, 1)

    User.pre_cache_users(:active)
    Teiserver.Data.Matchmaking.pre_cache_queues()

    springids = Account.list_users(order_by: "Newest first")
    |> Enum.map(fn u -> Central.Helpers.NumberHelper.int_parse(u.data["springid"]) end)

    # We do this as a separate operation because a blank DB won't have any springids yet
    current_springid = Enum.max([0] ++ springids)

    ConCache.put(:id_counters, :springid, current_springid + 1)

    ConCache.put(:application_metadata_cache, "teiserver_startup_completed", true)
    ConCache.put(:application_metadata_cache, "teiserver_day_metrics_today_last_time", nil)
    ConCache.put(:application_metadata_cache, "teiserver_day_metrics_today_cache", true)

    # User.pre_cache_users(:remaining)
    Teiserver.Telemetry.startup()

    if Application.get_env(:central, Teiserver)[:enable_match_monitor] do
      spawn(fn ->
        :timer.sleep(200)
        Teiserver.Battle.start_match_monitor()
      end)
    end

    if Application.get_env(:central, Teiserver)[:enable_coordinator_mode] do
      spawn(fn ->
        :timer.sleep(200)
        Teiserver.Coordinator.start_coordinator()
      end)
    end

    if Application.get_env(:central, Teiserver)[:enable_accolade_mode] do
      spawn(fn ->
        :timer.sleep(200)
        Teiserver.Account.AccoladeLib.start_accolade_server()
      end)
    end

    # We want this to start up later than the coordinator
    if Application.get_env(:central, Teiserver)[:enable_agent_mode] do
      spawn(fn ->
        :timer.sleep(650)
        Teiserver.agent_mode()
      end)
    end

    time_taken = System.system_time(:millisecond) - start_time
    Logger.info("Teiserver startup complete, took #{time_taken}ms")
  end
end
