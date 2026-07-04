defmodule Teiserver.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  alias Phoenix.PubSub
  alias Teiserver.Helper.ObanLogger
  alias Teiserver.Plugins
  alias Teiserver.Startup
  alias TeiserverWeb.Endpoint
  alias TeiserverWeb.Monitoring.Router, as: MonitoringRouter

  use Plugins
  use Application

  require Logger

  import Teiserver.Helpers.CacheHelper,
    only: [concache_sup: 1, concache_sup: 2, concache_perm_sup: 1]

  @impl Application
  def start(_type, _args) do
    LoggerBackends.add({LoggerFileBackend, :error_log})
    LoggerBackends.add({LoggerFileBackend, :notice_log})
    LoggerBackends.add({LoggerFileBackend, :info_log})
    Logger.add_handlers(:teiserver)

    # Topologies are only usable when running in distributed mode, otherwise
    # libcluster logs a warning on every reconnect attempt
    cluster_topologies =
      if Node.alive?() do
        Application.get_env(:libcluster, :topologies, [])
      else
        []
      end

    children =
      [
        Teiserver.PromEx,
        {Cluster.Supervisor, [cluster_topologies, [name: Teiserver.ClusterSupervisor]]},
        # Migrations
        {Ecto.Migrator,
         repos: Application.fetch_env!(:teiserver, :ecto_repos),
         skip: System.get_env("SKIP_MIGRATIONS") == "true"},

        # Start phoenix pubsub
        {Phoenix.PubSub, name: Teiserver.PubSub},
        {Task.Supervisor, name: Teiserver.TaskSupervisor},

        # Start the Ecto repository
        Teiserver.Repo,
        TeiserverWeb.Presence,
        {Teiserver.General.CacheClusterServer, name: Teiserver.General.CacheClusterServer},
        {Oban, Application.get_env(:teiserver, Oban, [])},

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
        Teiserver.General.RateLimit,

        # Teiserver stuff
        # Global/singleton registries
        {Horde.Registry, [keys: :unique, members: :auto, name: Teiserver.ServerRegistry]},
        {Horde.Registry, [keys: :unique, members: :auto, name: Teiserver.ThrottleRegistry]},
        {Horde.Registry, [keys: :unique, members: :auto, name: Teiserver.ConsulRegistry]},
        {Horde.Registry, [keys: :unique, members: :auto, name: Teiserver.BalancerRegistry]},
        {Horde.Registry, [keys: :unique, members: :auto, name: Teiserver.LobbyRegistry]},
        {Horde.Registry, [keys: :unique, members: :auto, name: Teiserver.ClientRegistry]},
        {Horde.Registry, [keys: :unique, members: :auto, name: Teiserver.PartyRegistry]},

        # Cluster-wide singletons (CoordinatorServer, MatchMonitorServer,
        # AutomodServer, LobbyIdServer); children of a dead node are restarted
        # on a surviving node
        {Horde.DynamicSupervisor,
         [strategy: :one_for_one, members: :auto, name: Teiserver.SingletonSupervisor]},

        # These are for tracking the number of servers on the local node
        {Registry, keys: :duplicate, name: Teiserver.LocalPoolRegistry},
        {Registry, keys: :duplicate, name: Teiserver.LocalServerRegistry},

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
        concache_sup(:user_mfa_active),

        # Caches - Chat
        Teiserver.Chat.RoomSystem,
        {Teiserver.HookServer, name: Teiserver.HookServer},

        # Liveview throttles
        Teiserver.Account.ClientIndexThrottle,
        Teiserver.Battle.LobbyIndexThrottle,
        {DynamicSupervisor, strategy: :one_for_one, name: Teiserver.Throttles.Supervisor},

        # Lobbies
        Teiserver.Lobby.Cache,
        {DynamicSupervisor, strategy: :one_for_one, name: Teiserver.LobbySupervisor},
        {DynamicSupervisor, strategy: :one_for_one, name: Teiserver.ClientSupervisor},
        {DynamicSupervisor, strategy: :one_for_one, name: Teiserver.PartySupervisor},

        # Coordinator mode
        {DynamicSupervisor,
         strategy: :one_for_one, name: Teiserver.Coordinator.DynamicSupervisor},
        {DynamicSupervisor,
         strategy: :one_for_one, name: Teiserver.Coordinator.BalancerDynamicSupervisor},

        # System throttle
        Teiserver.Account.LoginThrottleServer,

        # this must be before Endpoint. Endpoint takes care of ws connection upgrade
        # and makes use of the tachyon systems spawned under this module.
        Teiserver.Tachyon.System,

        # Telemetry
        {Teiserver.Telemetry.TelemetryServer, name: Teiserver.Telemetry.TelemetryServer},
        # serve metrics on a different port so that it's easier at the proxy
        # level to control access and scrape stuff
        {Plug.Cowboy,
         scheme: :http,
         plug: TeiserverWeb.Monitoring.Router,
         options: [port: MonitoringRouter.port()]},
        Teiserver.Communication.Cache,

        # Start the endpoint after the rest of the systems are up
        TeiserverWeb.Endpoint,

        # Start the ranch TCP listener process for the Spring protocol
        spring_server_child(Teiserver.RawSpringTcpServer, :tcp),
        # Start the ranch TLS listener process for the Spring protocol
        spring_server_child(Teiserver.SSLSpringTcpServer, :tls),

        # the discord system has a bot that connects to the tcp/tls server as a bot client
        # so it needs to be started after the servers
        Teiserver.Bridge.DiscordSystem
      ]
      |> Enum.reject(&is_nil/1)
      |> Kernel.++(additional_application_children())

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Teiserver.Supervisor]
    start_result = Supervisor.start_link(children, opts)

    # If the server seems to not start up we can check the info log to see
    # if this is present, we don't want it appearing in our tests though
    # TODO: Replace this with something having less of a code-smell
    if not Application.get_env(:teiserver, Teiserver)[:test_mode] do
      Logger.error("Teiserver.Supervisor start result: #{Kernel.inspect(start_result)}")
    end

    startup_sub_functions(start_result)

    start_result
  end

  def startup_sub_functions({:error, _reason}), do: :error

  def startup_sub_functions(_result) do
    :timer.sleep(100)

    # Oban logging
    events = [
      [:oban, :job, :start],
      [:oban, :job, :stop],
      [:oban, :job, :exception],
      [:oban, :circuit, :trip]
    ]

    :telemetry.attach_many("oban-logger", events, &ObanLogger.handle_event/4, [])

    Startup.startup()
  end

  @decorate Plugins.plugin(:additional_application_children)
  defp additional_application_children do
    []
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl Application
  def config_change(changed, _new, removed) do
    Endpoint.config_change(changed, removed)
    :ok
  end

  @impl Application
  @spec prep_stop(map()) :: map()
  def prep_stop(state) do
    # TODO - PubSub doesn't work here because the endpoint is already stopped
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

  def spring_server_child(ref, transport_type) do
    listeners =
      Application.get_env(:teiserver, Teiserver.SpringTcpServer)
      |> Keyword.fetch!(:listeners)

    if Keyword.get(listeners, :disable_startup) != true do
      listeners
      |> Keyword.get(transport_type, [])
      |> spring_server_listener_child(ref, transport_type)
    end
  end

  # When the listener is not configured we dont start the listener
  defp spring_server_listener_child(listener_opts, _ref, _transport)
       when listener_opts in [nil, false, []],
       do: nil

  defp spring_server_listener_child(listener_opts, ref, :tcp) when is_list(listener_opts) do
    listener_opts = Map.new(listener_opts)
    :ranch.child_spec(ref, :ranch_tcp, listener_opts, Teiserver.SpringTcpServer, [])
  end

  defp spring_server_listener_child(listener_opts, ref, :tls) when is_list(listener_opts) do
    listener_opts = Map.new(listener_opts)
    :ranch.child_spec(ref, :ranch_ssl, listener_opts, Teiserver.SpringTcpServer, [])
  end
end
