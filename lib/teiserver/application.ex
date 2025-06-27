defmodule Teiserver.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  alias Phoenix.PubSub
  require Logger

  import Teiserver.Helpers.CacheHelper,
    only: [concache_sup: 1, concache_sup: 2, concache_perm_sup: 1]

  @impl true
  def start(_type, _args) do
    LoggerBackends.add(LoggerBackends.Console)
    LoggerBackends.add({LoggerFileBackend, :error_log})
    LoggerBackends.add({LoggerFileBackend, :notice_log})
    LoggerBackends.add({LoggerFileBackend, :info_log})

    # List all child processes to be supervised
    children =
      [
        # Migrations
        {Ecto.Migrator,
         repos: Application.fetch_env!(:teiserver, :ecto_repos),
         skip: System.get_env("SKIP_MIGRATIONS") == "true"},

        # Start phoenix pubsub
        {Phoenix.PubSub, name: Teiserver.PubSub},
        TeiserverWeb.Telemetry,

        # Start the Ecto repository
        Teiserver.Repo,
        TeiserverWeb.Presence,
        {Teiserver.General.CacheClusterServer, name: Teiserver.General.CacheClusterServer},
        {Oban, oban_config()},

        # Store refers to something that is typically only updated at startup
        # and should not be clustered

        concache_sup(:lists),
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
        Teiserver.Account.PermissionCache,
        Teiserver.Config.UserConfigTypes.Cache,
        Teiserver.Config.SiteConfigTypes.Cache,
        Teiserver.MetadataCache,
        concache_sup(:application_temp_cache),
        concache_sup(:config_user_cache),

        # Teiserver stuff
        # Global/singleton registries
        {Horde.Registry, [keys: :unique, members: :auto, name: Teiserver.ServerRegistry]},
        {Horde.Registry, [keys: :unique, members: :auto, name: Teiserver.ThrottleRegistry]},
        {Horde.Registry, [keys: :unique, members: :auto, name: Teiserver.AccoladesRegistry]},
        {Horde.Registry, [keys: :unique, members: :auto, name: Teiserver.ConsulRegistry]},
        {Horde.Registry, [keys: :unique, members: :auto, name: Teiserver.BalancerRegistry]},
        {Horde.Registry, [keys: :unique, members: :auto, name: Teiserver.LobbyRegistry]},
        {Horde.Registry, [keys: :unique, members: :auto, name: Teiserver.ClientRegistry]},
        {Horde.Registry, [keys: :unique, members: :auto, name: Teiserver.PartyRegistry]},
        {Horde.Registry, [keys: :unique, members: :auto, name: Teiserver.QueueWaitRegistry]},
        {Horde.Registry, [keys: :unique, members: :auto, name: Teiserver.QueueMatchRegistry]},
        {Horde.Registry, [keys: :unique, members: :auto, name: Teiserver.LobbyPolicyRegistry]},

        # These are for tracking the number of servers on the local node
        {Registry, keys: :duplicate, name: Teiserver.LocalPoolRegistry},
        {Registry, keys: :duplicate, name: Teiserver.LocalServerRegistry},

        # Stores - Tables where changes are not propagated across the cluster
        # Possible stores
        Teiserver.Data.LobbyPolicyCache,

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
        {Teiserver.HookServer, name: Teiserver.HookServer},

        # Liveview throttles
        Teiserver.Account.ClientIndexThrottle,
        Teiserver.Battle.LobbyIndexThrottle,
        {DynamicSupervisor, strategy: :one_for_one, name: Teiserver.Throttles.Supervisor},

        # Bridge
        Teiserver.Bridge.DiscordSystem,
        concache_sup(:discord_bridge_dm_cache),
        concache_perm_sup(:discord_channel_cache),
        concache_sup(:discord_bridge_account_codes, global_ttl: 300_000),
        concache_perm_sup(:discord_command_cache),

        # Lobbies
        Teiserver.Lobby.Cache,
        {DynamicSupervisor, strategy: :one_for_one, name: Teiserver.LobbySupervisor},
        {DynamicSupervisor, strategy: :one_for_one, name: Teiserver.ClientSupervisor},
        {DynamicSupervisor, strategy: :one_for_one, name: Teiserver.PartySupervisor},
        {DynamicSupervisor, strategy: :one_for_one, name: Teiserver.LobbyPolicySupervisor},

        # Coordinator mode
        {DynamicSupervisor,
         strategy: :one_for_one, name: Teiserver.Coordinator.DynamicSupervisor},
        {DynamicSupervisor,
         strategy: :one_for_one, name: Teiserver.Coordinator.BalancerDynamicSupervisor},

        # Accolades
        {DynamicSupervisor, strategy: :one_for_one, name: Teiserver.Account.AccoladeSupervisor},

        # Achievements
        {Teiserver.Game.AchievementServer, name: Teiserver.Game.AchievementServer},

        # System throttle
        {Teiserver.Account.LoginThrottleServer, name: Teiserver.Account.LoginThrottleServer},

        # Telemetry
        {Teiserver.Telemetry.TelemetryServer, name: Teiserver.Telemetry.TelemetryServer},
        Teiserver.Communication.Cache,

        # this must be before Endpoint. Endpoint takes care of ws connection upgrade
        # and makes use of the tachyon systems spawned under this module.
        Teiserver.Tachyon.System,

        # Start the endpoint after the rest of the systems are up
        TeiserverWeb.Endpoint,

        # Ranch servers
        %{
          id: Teiserver.SSLSpringTcpServer,
          start: {Teiserver.SpringTcpServer, :start_link, [[ssl: true]]}
        },
        %{
          id: Teiserver.RawSpringTcpServer,
          start: {Teiserver.SpringTcpServer, :start_link, [[]]}
        }
      ]

    children = Enum.filter(children, fn x -> not is_nil(x) end)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Teiserver.Supervisor]
    start_result = Supervisor.start_link(children, opts)

    # We use a logger.error to ensure something appears even on the error logs
    # and we can be sure they're being written to
    Logger.error("Teiserver.Supervisor start result: #{Kernel.inspect(start_result)}")

    startup_sub_functions(start_result)

    start_result
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

    :telemetry.attach_many("oban-logger", events, &Teiserver.Helper.ObanLogger.handle_event/4, [])

    Teiserver.Startup.startup()
  end

  defp oban_config do
    Application.get_env(:teiserver, Oban)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TeiserverWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  @impl true
  @spec prep_stop(map()) :: map()
  def prep_stop(state) do
    PubSub.broadcast(
      Teiserver.PubSub,
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
