defmodule Teiserver.Startup do
  use CentralWeb, :startup
  require Logger

  def startup do
    ConCache.put(:id_counters, :startup, 0)

    add_permission_set("teiserver", "admin", ~w(account battle clan party queue tournament))
    add_permission_set("teiserver", "moderator", ~w(account battle clan party queue tournament))
    add_permission_set("teiserver", "player", ~w(account))

    add_group_type("Bar team", %{fields: []})

    umbrella =
      case Central.Account.get_group(nil, search: [name: "BAR umbrella group"]) do
        nil ->
          {:ok, group} =
            Central.Account.create_group(%{
              "name" => "BAR umbrella group",
              "active" => true,
              "icon" => "fas fa-umbrella",
              "colour" => "#00AA66",
              "data" => %{}
            })

          group

        group ->
          group
      end

    group =
      case Central.Account.get_group(nil, search: [name: "BAR Users"]) do
        nil ->
          {:ok, group} =
            Central.Account.create_group(%{
              "name" => "BAR Users",
              "active" => true,
              "icon" => "fas fa-robot",
              "colour" => "#000000",
              "data" => %{},
              "super_group_id" => umbrella.id
            })

          group

        group ->
          group
      end

    ConCache.put(:application_metadata_cache, "bar_umbrella_group", umbrella.id)
    ConCache.put(:application_metadata_cache, "bar_user_group", group.id)

    Central.Account.GroupCacheLib.update_caches(umbrella)
    Central.Account.GroupCacheLib.update_caches(group)

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
        label: "Clans",
        icons: [Teiserver.Clans.ClanLib.icon(), :list],
        url: "/teiserver/account/clans",
        permissions: "teiserver"
      },
      %{
        label: "Battles",
        icons: [Teiserver.BattleLib.icon(), :list],
        url: "/teiserver/battle",
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
        label: "Teiserver users",
        icons: [Teiserver.ClientLib.icon(), :list],
        url: "/teiserver/admin/users",
        permissions: "teiserver.moderator"
      },
      # %{label: "Parties", icons: [Teiserver.ClientLib.icon(), :list], url: "/teiserver/admin/parties", permissions: "teiserver.moderator"},
      %{
        label: "Clan admin",
        icons: [Teiserver.Clans.ClanLib.icon(), :list],
        url: "/teiserver/admin/clans",
        permissions: "teiserver.moderator"
      }
      # %{label: "Queue admin", icons: [Teiserver.ClientLib.icon(), :list], url: "/teiserver/admin/queues", permissions: "teiserver.moderator"},
      # %{label: "Tournament admin", icons: [Teiserver.Game.TournamentLib.icon(), :list], url: "/teiserver/admin/tournaments", permissions: "teiserver.moderator"},

      # Admin pages
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

    ConCache.put(:id_counters, :battle, 0)

    Teiserver.User.pre_cache_users()
    Teiserver.Data.Matchmaking.pre_cache_queues()

    ConCache.put(:id_counters, :startup, 1)

    Logger.info("Teiserver startup complete")
  end
end
