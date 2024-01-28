defmodule Barserver.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  alias Phoenix.PubSub
  require Logger

  @impl true
  def start(_type, _args) do
    # List all child processes to be supervised
    children =
      [
        # Migrations
        {Ecto.Migrator,
         repos: Application.fetch_env!(:teiserver, :ecto_repos),
         skip: System.get_env("SKIP_MIGRATIONS") == "true"},

        # Start phoenix pubsub
        {Phoenix.PubSub, name: Barserver.PubSub},
        BarserverWeb.Telemetry,

        # Start the Ecto repository
        Barserver.Repo,
        # Start the endpoint when the application starts
        BarserverWeb.Endpoint,
        BarserverWeb.Presence,
        {Barserver.General.CacheClusterServer, name: Barserver.General.CacheClusterServer},
        {Oban, oban_config()},

        # Store refers to something that is typically only updated at startup
        # and should not be clustered

        concache_sup(:codes),
        concache_sup(:account_user_cache),
        concache_sup(:account_user_cache_bang),
        concache_sup(:account_membership_cache),
        concache_sup(:account_friend_cache),
        concache_sup(:account_incoming_friend_request_cache),
        concache_sup(:account_outgoing_friend_request_cache),
        concache_sup(:account_follow_cache),
        concache_sup(:account_ignore_cache),
        concache_sup(:account_avoid_cache),
        concache_sup(:account_block_cache),
        concache_sup(:account_avoiding_this_cache),
        concache_sup(:account_blocking_this_cache),
        concache_perm_sup(:recently_used_cache),
        concache_perm_sup(:auth_group_store),
        concache_perm_sup(:restriction_lookup_store),
        concache_perm_sup(:config_user_type_store),
        concache_perm_sup(:config_site_type_store),
        concache_perm_sup(:config_site_cache),
        concache_perm_sup(:application_metadata_cache),
        concache_sup(:application_temp_cache),
        concache_sup(:config_user_cache),

        # Tachyon schemas
        concache_perm_sup(:tachyon_schemas),
        concache_perm_sup(:tachyon_dispatches),

        # Barserver stuff
        # Global/singleton registries
        {Horde.Registry, [keys: :unique, members: :auto, name: Barserver.ServerRegistry]},
        {Horde.Registry, [keys: :unique, members: :auto, name: Barserver.ThrottleRegistry]},
        {Horde.Registry, [keys: :unique, members: :auto, name: Barserver.AccoladesRegistry]},
        {Horde.Registry, [keys: :unique, members: :auto, name: Barserver.ConsulRegistry]},
        {Horde.Registry, [keys: :unique, members: :auto, name: Barserver.BalancerRegistry]},
        {Horde.Registry, [keys: :unique, members: :auto, name: Barserver.LobbyRegistry]},
        {Horde.Registry, [keys: :unique, members: :auto, name: Barserver.ClientRegistry]},
        {Horde.Registry, [keys: :unique, members: :auto, name: Barserver.PartyRegistry]},
        {Horde.Registry, [keys: :unique, members: :auto, name: Barserver.QueueWaitRegistry]},
        {Horde.Registry, [keys: :unique, members: :auto, name: Barserver.QueueMatchRegistry]},
        {Horde.Registry, [keys: :unique, members: :auto, name: Barserver.LobbyPolicyRegistry]},

        # These are for tracking the number of servers on the local node
        {Registry, keys: :duplicate, name: Barserver.LocalPoolRegistry},
        {Registry, keys: :duplicate, name: Barserver.LocalServerRegistry},

        # Stores - Tables where changes are not propagated across the cluster
        # Possible stores
        concache_perm_sup(:teiserver_queues),
        concache_perm_sup(:lobby_policies_cache),

        # Telemetry
        concache_perm_sup(:telemetry_property_types_cache),
        concache_perm_sup(:telemetry_simple_client_event_types_cache),
        concache_perm_sup(:telemetry_complex_client_event_types_cache),
        concache_perm_sup(:telemetry_simple_lobby_event_types_cache),
        concache_perm_sup(:telemetry_complex_lobby_event_types_cache),
        concache_perm_sup(:telemetry_simple_match_event_types_cache),
        concache_perm_sup(:telemetry_complex_match_event_types_cache),
        concache_perm_sup(:telemetry_simple_server_event_types_cache),
        concache_perm_sup(:telemetry_complex_server_event_types_cache),
        concache_perm_sup(:teiserver_account_smurf_key_types),
        concache_sup(:teiserver_user_ratings, global_ttl: 60_000),
        concache_sup(:teiserver_game_rating_types, global_ttl: 60_000),

        # Caches
        # Caches - Meta
        concache_perm_sup(:lists),

        # Caches - User
        # concache_sup(:users_lookup_name_with_id, [global_ttl: 300_000]),
        # concache_sup(:users_lookup_id_with_name, [global_ttl: 300_000]),
        # concache_sup(:users_lookup_id_with_email, [global_ttl: 300_000]),
        # concache_sup(:users_lookup_id_with_discord, [global_ttl: 300_000]),
        # concache_sup(:users, [global_ttl: 300_000]),

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
        {Barserver.HookServer, name: Barserver.HookServer},

        # Liveview throttles
        Barserver.Account.ClientIndexThrottle,
        Barserver.Battle.LobbyIndexThrottle,
        {DynamicSupervisor, strategy: :one_for_one, name: Barserver.Throttles.Supervisor},

        # Bridge
        Barserver.Bridge.BridgeServer,
        concache_sup(:discord_bridge_dm_cache),
        concache_perm_sup(:discord_channel_cache),
        concache_sup(:discord_bridge_account_codes, global_ttl: 300_000),
        concache_perm_sup(:discord_command_cache),

        # Lobbies
        concache_perm_sup(:lobby_command_cache),
        {DynamicSupervisor, strategy: :one_for_one, name: Barserver.LobbySupervisor},
        {DynamicSupervisor, strategy: :one_for_one, name: Barserver.ClientSupervisor},
        {DynamicSupervisor, strategy: :one_for_one, name: Barserver.PartySupervisor},
        {DynamicSupervisor, strategy: :one_for_one, name: Barserver.LobbyPolicySupervisor},

        # Matchmaking
        {DynamicSupervisor, strategy: :one_for_one, name: Barserver.Game.QueueSupervisor},

        # Coordinator mode
        {DynamicSupervisor,
         strategy: :one_for_one, name: Barserver.Coordinator.DynamicSupervisor},
        {DynamicSupervisor,
         strategy: :one_for_one, name: Barserver.Coordinator.BalancerDynamicSupervisor},

        # Accolades
        {DynamicSupervisor, strategy: :one_for_one, name: Barserver.Account.AccoladeSupervisor},

        # Achievements
        {Barserver.Game.AchievementServer, name: Barserver.Game.AchievementServer},

        # System throttle
        {Barserver.Account.LoginThrottleServer, name: Barserver.Account.LoginThrottleServer},

        # Telemetry
        {Barserver.Telemetry.TelemetryServer, name: Barserver.Telemetry.TelemetryServer},

        # Text callbacks
        concache_perm_sup(:text_callback_trigger_lookup),
        concache_perm_sup(:text_callback_store),

        # Ranch servers
        %{
          id: Barserver.SSLSpringTcpServer,
          start: {Barserver.SpringTcpServer, :start_link, [[ssl: true]]}
        },
        %{
          id: Barserver.RawSpringTcpServer,
          start: {Barserver.SpringTcpServer, :start_link, [[]]}
        },
        %{
          id: Barserver.TachyonTcpServer,
          start: {Barserver.TachyonTcpServer, :start_link, [[]]}
        }
      ] ++ discord_start()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Barserver.Supervisor]
    start_result = Supervisor.start_link(children, opts)

    # We use a logger.error to ensure something appears even on the error logs
    # and we can be sure they're being written to
    Logger.error("Barserver.Supervisor start result: #{Kernel.inspect(start_result)}")

    startup_sub_functions(start_result)

    start_result
  end

  defp discord_start do
    if Barserver.Communication.use_discord?() do
      [{Barserver.Bridge.DiscordBridgeBot, name: Barserver.Bridge.DiscordBridgeBot}]
    else
      []
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

  def startup_sub_functions({:error, _}), do: :error

  def startup_sub_functions(_) do
    :timer.sleep(100)

    # Oban logging
    events = [
      [:oban, :job, :start],
      [:oban, :job, :stop],
      [:oban, :job, :exception],
      [:oban, :circuit, :trip]
    ]

    :telemetry.attach_many("oban-logger", events, &Barserver.Helper.ObanLogger.handle_event/4, [])

    Barserver.Startup.startup()
  end

  defp oban_config do
    Application.get_env(:teiserver, Oban)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BarserverWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  @impl true
  @spec prep_stop(map()) :: map()
  def prep_stop(state) do
    PubSub.broadcast(
      Barserver.PubSub,
      "application",
      %{
        channel: "application",
        event: :prep_stop,
        node: Node.self()
      }
    )

    state
  end
end
