import Config

config :central, Central,
  site_title: "BAR",
  site_description: "",
  site_icon: "fad fa-robot",
  enable_blog: false,
  blog_title: "BAR Blog",
  # This is used for the coverage tool
  file_path: "~/programming/elixir/barserver/",
  credit: "Teifion Jordan"

# Default configs
config :central, Central.Config,
  defaults: %{
    tz: "UTC"
  }

config :central,
  ecto_repos: [Central.Repo]

config :central, Extensions,
  applications: [Teiserver.Application],
  startups: [Teiserver.Startup],
  routers: [TeiserverWeb.Router],
  index_views: [TeiserverWeb.General.CentralView],
  side_views: [TeiserverWeb.General.CentralView]

# Configures the endpoint
config :central, CentralWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "6FN12Jv4ZITAK1fq7ehD0MTRvbLsXYWj+wLY3ifkzzlcUIcpUJK7aG/ptrJSemAy",
  live_view: [signing_salt: "wZVVigZo"],
  render_errors: [view: CentralWeb.ErrorView, accepts: ~w(html json)],
  # render_errors: [view: CentralWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Central.PubSub

config :esbuild,
  version: "0.12.18",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2016 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :central, Teiserver,
  ports: [
    tcp: 8200,
    tls: 8201
  ],
  website: [
    url: "https://server2.beyondallreason.info"
  ],
  enable_benchmark: false,
  enable_hooks: true,
  autologin: false,

  # Heatbeat interval is ms
  heartbeat_interval: 30_000,
  # Heartbeat timeout is seconds
  heartbeat_timeout: 120,

  game_name: "Spring game",
  game_name_short: "SG",
  main_website: "https://site.com/",
  discord: nil,
  default_protocol: Teiserver.Protocols.Spring,
  github_repo: "https://github.com/beyond-all-reason/teiserver",
  enable_discord_bridge: false,
  enable_coordinator_mode: true,
  enable_agent_mode: false,
  enable_uberserver_convert: false,
  enable_match_monitor: true,
  user_agreement: "User agreement goes here.",
  server_flag: "GB",
  post_login_delay: 100,
  spring_post_state_change_delay: 100,
  user_agreement: "A verification code has been sent to your email address. Please read our terms of service at <<<site_url>>> and the code of conduct at <<<URL>>>. Then enter your six digit code below if you agree to the terms.",
  use_geoip: true

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# This secret key is overwritten in prod.secret.exs
config :central, Central.Account.Guardian,
  issuer: "central",
  secret_key: "9vJcJOYwsjdIQ9IhfOI5F9GQMykuNjBW58FY9S/TqMsq6gRdKgY05jscQAFVKfwa",
  ttl: {30, :days}

config :central, Central.Communication.BlogFile, save_path: "/etc/central/blog_files"

config :central, Oban,
  repo: Central.Repo,
  plugins: [
    {Oban.Plugins.Pruner, max_age: 3600},
    {Oban.Plugins.Cron,
      crontab: [
        # Every hour
        {"0 * * * *", Central.Admin.CleanupTask},

        # Every day at 2am
        {"0 2 * * *", Central.Logging.AggregateViewLogsTask},

        # Every minute
        {"* * * * *", Teiserver.Account.Tasks.CleanupTask},

        # 1:05 am
        {"5 1 * * *", Teiserver.Account.Tasks.DailyCleanupTask},

        # Every minute
        {"* * * * *", Teiserver.Telemetry.Tasks.PersistServerMinuteTask},

        # Every 5 minutes
        {"*/5 * * * *", Teiserver.Battle.Tasks.PostMatchProcessTask},

        # 2:05 am and 2:15 am
        {"5 2 * * *", Teiserver.Telemetry.Tasks.PersistServerDayTask},
        {"15 2 * * *", Teiserver.Telemetry.Tasks.PersistServerMonthTask},

        {"5 2 * * *", Teiserver.Telemetry.Tasks.PersistMatchDayTask},
        {"15 2 * * *", Teiserver.Telemetry.Tasks.PersistMatchMonthTask},

        # 3:05 am every day, gives time for multiple telemetry day tasks to run if needed
        {"5 3 * * *", Teiserver.Account.RecalculateUserStatTask},
        {"5 12 * * *", Teiserver.Account.RecalculateUserStatTask},
        {"5 4 * * *", Teiserver.Account.RecalculateUserHWTask},
      ]
    }
  ],
  queues: [logging: 1, cleanup: 1, teiserver: 10]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
