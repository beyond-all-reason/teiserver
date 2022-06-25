defmodule Teiserver.Application do
  @moduledoc false
  def children() do
    children = [
      # Global/singleton registries
      # {Horde.Registry, [keys: :duplicate, members: :auto, name: Teiserver.PoolRegistry]},
      {Horde.Registry, [keys: :unique, members: :auto, name: Teiserver.ServerRegistry]},
      {Horde.Registry, [keys: :unique, members: :auto, name: Teiserver.LobbyRegistry]},
      {Horde.Registry, [keys: :unique, members: :auto, name: Teiserver.ClientRegistry]},
      {Horde.Registry, [keys: :unique, members: :auto, name: Teiserver.PartyRegistry]},

      # These are for tracking the number of servers on the local node
      {Registry, keys: :duplicate, name: Teiserver.LocalPoolRegistry},
      {Registry, keys: :duplicate, name: Teiserver.LocalServerRegistry},

      # Stores - Tables where changes are not propagated across the cluster
      # Possible stores
      concache_perm_sup(:teiserver_queues),

      # Telemetry
      concache_perm_sup(:teiserver_telemetry_event_types),
      concache_perm_sup(:teiserver_telemetry_property_types),
      concache_perm_sup(:teiserver_telemetry_game_event_types),
      concache_perm_sup(:teiserver_account_smurf_key_types),

      # Caches
      # Caches - Meta
      concache_perm_sup(:lists),

      # Caches - User
      concache_perm_sup(:users_lookup_name_with_id),
      concache_perm_sup(:users_lookup_id_with_name),
      concache_perm_sup(:users_lookup_id_with_email),
      concache_perm_sup(:users_lookup_id_with_discord),
      concache_perm_sup(:users),

      concache_sup(:teiserver_login_count, global_ttl: 10_000),
      concache_sup(:teiserver_user_stat_cache),

      # Caches - Battle/Queue/Clan
      concache_sup(:teiserver_clan_cache_bang),

      # Caches - Chat
      concache_perm_sup(:rooms),

      # Caches - Blog - TODO: Is this actually needed? It's not in use
      concache_sup(:teiserver_blog_posts),
      concache_sup(:teiserver_blog_categories),

      {Teiserver.HookServer, name: Teiserver.HookServer},

      # Liveview throttles
      Teiserver.Account.ClientIndexThrottle,
      {DynamicSupervisor, strategy: :one_for_one, name: Teiserver.Throttles.Supervisor},

      # Bridge
      Teiserver.Bridge.BridgeServer,
      concache_sup(:discord_bridge_dm_cache),
      concache_sup(:discord_bridge_account_codes, global_ttl: 300_000),

      # Lobbies
      {DynamicSupervisor, strategy: :one_for_one, name: Teiserver.LobbySupervisor},
      {DynamicSupervisor, strategy: :one_for_one, name: Teiserver.ClientSupervisor},
      {DynamicSupervisor, strategy: :one_for_one, name: Teiserver.PartySupervisor},

      # Matchmaking
      {DynamicSupervisor, strategy: :one_for_one, name: Teiserver.Game.QueueSupervisor},

      # Coordinator mode
      {DynamicSupervisor, strategy: :one_for_one, name: Teiserver.Coordinator.DynamicSupervisor},
      # {Teiserver.Coordinator.AutomodServer, name: Teiserver.Coordinator.AutomodServer},

      # Accolades
      {DynamicSupervisor, strategy: :one_for_one, name: Teiserver.Account.AccoladeSupervisor},

      # Achievements
      {Teiserver.Game.AchievementServer, name: Teiserver.Game.AchievementServer},

      # Telemetry
      {Teiserver.Telemetry.TelemetryServer, name: Teiserver.Telemetry.TelemetryServer},
      {Teiserver.Telemetry.SpringTelemetryServer, name: Teiserver.Telemetry.SpringTelemetryServer},

      # Ranch servers
      %{
        id: Teiserver.SSLSpringTcpServer,
        start: {Teiserver.SpringTcpServer, :start_link, [[ssl: true]]}
      },
      %{
        id: Teiserver.RawSpringTcpServer,
        start: {Teiserver.SpringTcpServer, :start_link, [[]]}
      },
      %{
        id: Teiserver.TachyonTcpServer,
        start: {Teiserver.TachyonTcpServer, :start_link, [[]]}
      }
    ]

    discord_start()

    # Agent mode stuff, should not be enabled in prod
    children = if Application.get_env(:central, Teiserver)[:enable_agent_mode] do
      children ++
        [
          {Registry, keys: :unique, name: Teiserver.Agents.ServerRegistry},
          {DynamicSupervisor, strategy: :one_for_one, name: Teiserver.Agents.DynamicSupervisor},
        ]
    else
      children
    end

    children
  end

  defp discord_start do
    if Application.get_env(:central, Teiserver)[:enable_discord_bridge] do
      token = Application.get_env(:central, DiscordBridge)[:token]
      {:ok, pid} = Alchemy.Client.start(token)
      use Teiserver.Bridge.DiscordBridge
      {:ok, pid}
    end
  end

  defp concache_sup(name, opts \\ []) do
    Supervisor.child_spec(
      {
        ConCache,
        [
          name: name,
          ttl_check_interval: 10_000,
          global_ttl: opts[:global_ttl] || 60_000,
          touch_on_read: true
        ]
      },
      id: {ConCache, name}
    )
  end

  defp concache_perm_sup(name) do
    Supervisor.child_spec(
      {
        ConCache,
        [
          name: name,
          ttl_check_interval: false
        ]
      },
      id: {ConCache, name}
    )
  end
end
