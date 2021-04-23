defmodule Central.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  def start(_type, _args) do
    # List all child processes to be supervised
    children =
      [
        # Start phoenix pubsub
        {Phoenix.PubSub, name: Central.PubSub},

        # Start the Ecto repository
        Central.Repo,
        # Start the endpoint when the application starts
        CentralWeb.Endpoint,
        # Starts a worker by calling: Central.Worker.start_link(arg)
        # {Central.Worker, arg}
        CentralWeb.Presence,
        CentralWeb.Telemetry,
        {Central.Account.RecentlyUsedCache, name: Central.Account.RecentlyUsedCache},
        {Central.Account.AuthGroups.Server, name: Central.Account.AuthGroups.Server},
        {Central.General.QuickAction.Cache, name: Central.General.QuickAction.Cache},
        concache_sup(:codes),
        concache_sup(:account_user_cache),
        concache_sup(:account_user_cache_bang),
        concache_sup(:account_membership_cache),
        concache_perm_sup(:group_type_cache),
        concache_perm_sup(:config_type_cache),
        concache_perm_sup(:application_metadata_cache),
        concache_sup(:config_user_cache),
        concache_sup(:communication_user_notifications),
        {Oban, oban_config()}
      ] ++
        load_test_server()

    extended_children =
      Application.get_env(:central, Extensions)[:applications]
      |> Enum.map(fn m ->
        m.children()
      end)
      |> List.flatten()

    children = children ++ extended_children

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Central.Supervisor]
    start_result = Supervisor.start_link(children, opts)

    startup_sub_functions()

    start_result
  end

  defp concache_sup(name) do
    Supervisor.child_spec(
      {
        ConCache,
        [
          name: name,
          ttl_check_interval: 10_000,
          global_ttl: 60_000,
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

  defp load_test_server() do
    env_flag =
      Application.get_env(:central, Central.General.LoadTestServer)
      |> Keyword.get(:enable_loadtest)

    if env_flag do
      [
        {Central.General.LoadTest.Server, name: Central.General.LoadTest.Server},
        {Central.General.LoadTest.Stats, name: Central.General.LoadTest.Stats}
      ]
    else
      []
    end
  end

  def startup_sub_functions do
    # Oban logging
    events = [
      [:oban, :job, :start],
      [:oban, :job, :stop],
      [:oban, :job, :exception],
      [:oban, :circuit, :trip]
    ]

    :telemetry.attach_many("oban-logger", events, &Central.ObanLogger.handle_event/4, [])

    ~w(General Config Account Admin Logging)
    |> Enum.map(&env_startup/1)

    Application.get_env(:central, Extensions)[:startups]
    |> Enum.each(fn m ->
      m.startup()
    end)
  end

  defp env_startup(module) do
    mstartup = Module.concat(["Central", module, "Startup"])
    mstartup.startup()
  end

  defp oban_config do
    Application.get_env(:central, Oban)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    CentralWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  def prep_stop(state) do
    CentralWeb.Endpoint.broadcast(
      "application",
      "prep_stop",
      %{}
    )

    state
  end
end
