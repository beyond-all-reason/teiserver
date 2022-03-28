defmodule Teiserver.Application do
  @moduledoc false
  def children() do
    children = [
      # Caches - Meta
      concache_perm_sup(:id_counters),
      concache_perm_sup(:lists),

      # Caches - User
      concache_perm_sup(:users_lookup_name_with_id),
      concache_perm_sup(:users_lookup_id_with_name),
      concache_perm_sup(:users_lookup_id_with_email),
      concache_perm_sup(:users_lookup_id_with_discord_id),
      concache_perm_sup(:users),
      concache_perm_sup(:clients),
      concache_sup(:teiserver_login_count, global_ttl: 10_000),
      concache_sup(:teiserver_user_stat_cache),

      # Caches - Battle/Queue/Clan
      concache_perm_sup(:lobbies),
      concache_perm_sup(:teiserver_queues),
      concache_sup(:teiserver_clan_cache_bang),

      # Caches - Chat
      concache_perm_sup(:rooms),

      # Caches - Blog
      concache_sup(:teiserver_blog_posts),
      concache_sup(:teiserver_blog_categories),

      # Caches - Telemetry
      concache_perm_sup(:teiserver_telemetry_event_types),
      concache_perm_sup(:teiserver_telemetry_property_types),

      {Teiserver.HookServer, name: Teiserver.HookServer},

      # Liveview throttles
      concache_sup(:teiserver_throttle_pids),
      Teiserver.Account.ClientIndexThrottle,
      {DynamicSupervisor, strategy: :one_for_one, name: Teiserver.Throttles.Supervisor},

      # Bridge
      Teiserver.Bridge.BridgeServer,
      concache_sup(:discord_bridge_dm_cache),
      concache_sup(:discord_bridge_account_codes, global_ttl: 300_000),

      # Matchmaking
      concache_perm_sup(:teiserver_queue_pids),
      {DynamicSupervisor, strategy: :one_for_one, name: Teiserver.Game.QueueSupervisor},
      {DynamicSupervisor, strategy: :one_for_one, name: Teiserver.Game.QueueMatchSupervisor},

      # Coordinator mode
      concache_perm_sup(:teiserver_consul_pids),
      {DynamicSupervisor, strategy: :one_for_one, name: Teiserver.Coordinator.DynamicSupervisor},
      {Teiserver.Coordinator.AutomodServer, name: Teiserver.Coordinator.AutomodServer},

      # Accolades
      concache_perm_sup(:teiserver_accolade_pids),
      {DynamicSupervisor, strategy: :one_for_one, name: Teiserver.Account.AccoladeSupervisor},

      # Achievements
      {Teiserver.Game.AchievementServer, name: Teiserver.Game.AchievementServer},

      # Telemetry
      {Teiserver.Telemetry.TelemetryServer, name: Teiserver.Telemetry.TelemetryServer},
      {Teiserver.Telemetry.SpringTelemetryServer, name: Teiserver.Telemetry.SpringTelemetryServer},

      # Registries
      {Registry, keys: :unique, name: Teiserver.ServerRegistry},
      {Registry, keys: :unique, name: Teiserver.ClientRegistry},

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
