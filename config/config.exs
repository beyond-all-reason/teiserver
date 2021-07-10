use Mix.Config

config :central, Central,
  site_title: "BAR - Teiserver",
  site_description: "",
  site_icon: "fad fa-robot",
  enable_blog: true,
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
  pubsub_server: Central.PubSub

config :central, Teiserver,
  ports: [
    tcp: 8200,
    tls: 8201
  ],
  website: [
    url: "https://teifion.co.uk"
  ],
  enable_benchmark: false,
  enable_hooks: true,
  autologin: false,
  heartbeat_interval: 30_000,
  heartbeat_timeout: 45_000,
  game_name: "Spring game",
  game_name_short: "SG",
  main_website: "https://site.com",
  discord: nil,
  default_protocol: Teiserver.Protocols.Spring,
  github_repo: "https://github.com/Teifion/teiserver",
  extra_logging: false,
  enable_agent_mode: false,
  enable_coordinator_mode: true,
  user_agreement: "User agreement goes here."

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# This secret key is overwritten in prod.secret.exs
config :central, Central.Account.Guardian,
  issuer: "central",
  secret_key: "8vJcJOYwsjdIQ9IhfOI5F9GQMykuNjBW58FY9S/TqMsq6gRdKgY05jscQAFVKfwa",
  ttl: {30, :days}

config :central, Central.General.LoadTestServer, enable_loadtest: false

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

        # Every minute
        {"* * * * *", Teiserver.Telemetry.Tasks.PersistTelemetryMinuteTask},
      ]
    }
  ],
  queues: [logging: 1, cleanup: 1, teiserver: 10]

config :central, Central.Mailer,
  noreply_name: "Teiserver Noreply",
  noreply_name: "Teiserver Contact",
  adapter: Bamboo.SMTPAdapter

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
