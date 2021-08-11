defmodule Teiserver.Startup do
  use CentralWeb, :startup
  require Logger

  def startup do
    add_permission_set("teiserver", "admin", ~w(account battle clan party queue tournament))
    add_permission_set("teiserver", "moderator", ~w(account battle clan party queue tournament))
    add_permission_set("teiserver", "api", ~w(battle))
    add_permission_set("teiserver", "player", ~w(account))

    add_group_type("Teiserver clan", %{fields: []})

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
      # %{label: "Tournaments", icons: [Teiserver.Game.TournamentLib.icon(), :list], url: "/teiserver/tournaments", permissions: "teiserver"},

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
      # %{label: "Queue admin", icons: [Teiserver.ClientLib.icon(), :list], url: "/teiserver/admin/queues", permissions: "teiserver.moderator"},
      # %{label: "Tournament admin", icons: [Teiserver.Game.TournamentLib.icon(), :list], url: "/teiserver/admin/tournaments", permissions: "teiserver.moderator"},

      # Admin pages
      %{
        label: "Teiserver metrics",
        icons: ["fa-regular fa-tachometer-alt", :list],
        url: "/logging/live/dashboard/metrics?nav=teiserver",
        permissions: "logging.live.show"
      },
      %{
        label: "Teiserver aggregate logs",
        icons: ["fa-regular fa-layer-group", :list],
        url: "/teiserver/admin/tools/day_metrics",
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
    ConCache.insert_new(:lists, :battles, [])

    # We were using :rand.uniform() but it wasn't being random
    # since we don't care about random random we're okay with this!
    bid = :erlang.system_time()
      |> to_string
      |> String.reverse()
      |> String.slice(0..5)
      |> String.to_integer()
    ConCache.put(:id_counters, :battle, bid)

    Teiserver.User.pre_cache_users()
    Teiserver.Data.Matchmaking.pre_cache_queues()

    springids = Teiserver.User.list_users()
    |> Enum.map(fn u -> Central.Helpers.NumberHelper.int_parse(u.springid) end)

    # We do this as a separate operation because a blank DB won't have any springids yet
    current_springid = Enum.max([0] ++ springids)

    ConCache.put(:id_counters, :springid, current_springid + 1)

    ConCache.put(:application_metadata_cache, "teiserver_startup_completed", true)
    ConCache.put(:application_metadata_cache, "teiserver_day_metrics_today_last_time", nil)
    ConCache.put(:application_metadata_cache, "teiserver_day_metrics_today_cache", true)

    Teiserver.Telemetry.startup()

    if Application.get_env(:central, Teiserver)[:enable_match_monitor] do
      spawn(fn ->
        :timer.sleep(500)
        Teiserver.Battle.start_match_monitor()
      end)
    end

    if Application.get_env(:central, Teiserver)[:enable_coordinator_mode] do
      spawn(fn ->
        :timer.sleep(500)
        Teiserver.Coordinator.start_coordinator()
      end)
    end

    # We want this to start up later than the coordinator
    if Application.get_env(:central, Teiserver)[:enable_agent_mode] do
      spawn(fn ->
        :timer.sleep(650)
        Teiserver.agent_mode()
      end)
    end

    Logger.info("Teiserver startup complete")
  end
end
