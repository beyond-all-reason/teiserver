import Config

config :iex,
  ansi_enabled: true

config :teiserver, Teiserver,
  site_title: "BAR",
  site_suffix: "",
  site_description: "",
  site_icon: "fa-solid fa-robot",
  credit: "Teifion Jordan"

# Default configs
config :teiserver, Teiserver.Config,
  defaults: %{
    tz: "UTC"
  }

config :teiserver,
  ecto_repos: [Teiserver.Repo],
  blog_allow_upload: true,
  blog_upload_path: "zignore/uploads",
  blog_upload_extensions: ~w(.jpg .jpeg .png)

# Configures the endpoint
config :teiserver, TeiserverWeb.Endpoint,
  url: [host: "localhost"],
  # This is overriden in your secret config, it's here only to allow things to run easily
  secret_key_base: "6FN12Jv4ZITAK1fq7ehD0MTRvbLsXYWj+wLY3ifkzzlcUIcpUJK7aG/ptrJSemAy",
  live_view: [signing_salt: "wZVVigZo"],
  render_errors: [
    formats: [html: TeiserverWeb.ErrorHTML, json: TeiserverWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Teiserver.PubSub,
  debug_errors: Config.config_env() == :dev,
  code_reloader: Config.config_env() == :dev,
  check_origin: Config.config_env() == :prod

config :esbuild,
  version: "0.14.41",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2016 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :teiserver, Teiserver,
  ports: [
    tcp: 8200,
    tls: 8201
  ],
  website: [
    url: "mywebsite.com"
  ],
  enable_benchmark: false,
  enable_hooks: true,

  # Heatbeat interval is ms
  heartbeat_interval: 30_000,
  # Heartbeat timeout is seconds
  heartbeat_timeout: 120,
  test_mode: false,
  server_admin_name: "Server Admin",
  game_name: "Full game name",
  game_name_short: "Game",
  main_website: "https://site.com/",
  discord: nil,
  default_spring_protocol: Teiserver.Protocols.Spring,
  github_repo: "https://github.com/beyond-all-reason/teiserver",
  enable_discord_bridge: true,
  enable_coordinator_mode: true,
  enable_managed_lobbies: false,
  enable_accolade_mode: true,
  enable_match_monitor: true,
  bot_email_domain: "teiserver",
  user_agreement: "User agreement goes here.",
  server_flag: "GB",
  post_login_delay: 150,
  spring_post_state_change_delay: 150,
  user_agreement:
    "A verification code has been sent to your email address. Please read our terms of service at <<<site_url>>> and the code of conduct at <<<URL>>>. Then enter your six digit code below if you agree to the terms.",
  accept_all_emails: false,
  retention: %{
    telemetry_infolog: 31,
    telemetry_events: 90,
    battle_match_rated: 365,
    battle_match_unrated: 365,
    account_unverified: 14,
    lobby_chat: 90,
    room_chat: 90,
    battle_minimum_seconds: 120
  }

# config :grpc,
#   start_server: true

config :logger, :default_handler, false

metadata = [:request_id, :user_id, :pid, :actor_type, :actor_id]

config :logger, LoggerBackends.Console,
  format: "$date $time [$level] $metadata $message\n",
  metadata: metadata,
  level: :debug

config :logger, :error_log,
  format: "$date $time [$level] $metadata $message\n",
  metadata: metadata,
  level: :error,
  truncate: 16384

config :logger, :notice_log,
  format: "$date $time [$level] $metadata $message\n",
  metadata: metadata,
  level: :notice

config :logger, :info_log,
  format: "$date $time [$level] $metadata $message\n",
  metadata: metadata,
  level: :info

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# This secret key is overwritten in prod.secret.exs
config :teiserver, Teiserver.Account.Guardian,
  issuer: "teiserver",
  # This is overriden in your secret config, it's here only to allow things to run easily
  secret_key: "9vJcJOYwsjdIQ9IhfOI5F9GQMykuNjBW58FY9S/TqMsq6gRdKgY05jscQAFVKfwa",
  ttl: {30, :days}

config :teiserver, Oban,
  repo: Teiserver.Repo,
  plugins: [
    {Oban.Plugins.Pruner, max_age: 3600},
    {Oban.Plugins.Cron,
     crontab: [
       # Every hour
       {"0 * * * *", Teiserver.Admin.HourlyCleanupTask},

       # Every day at 8am
       {"0 8 * * *", Teiserver.Admin.DailyCleanupTask},

       # Every day at 9am
       {"0 9 * * *", Teiserver.Logging.AggregateViewLogsTask},

       # 1:07 am
       {"7 1 * * *", Teiserver.Account.Tasks.DailyCleanupTask},
       {"22 1 * * *", Teiserver.Telemetry.EventCleanupTask},
       {"7 1 * * *", Teiserver.OAuth.Tasks.Cleanup},

       # At 17 minutes past every hour
       {"17 * * * *", Teiserver.Battle.Tasks.CleanupTask},

       # Every minute
       {"* * * * *", Teiserver.Logging.Tasks.PersistServerMinuteTask},
       {"* * * * *", Teiserver.Moderation.RefreshUserRestrictionsTask},

       # Every minute
       {"* * * * *", Teiserver.Battle.Tasks.PostMatchProcessTask},

       # 9am
       {"1 9 * * *", Teiserver.Logging.Tasks.PersistServerDayTask},
       {"2 9 * * *", Teiserver.Logging.Tasks.PersistServerWeekTask},
       {"3 9 * * *", Teiserver.Logging.Tasks.PersistServerMonthTask},
       {"4 9 * * *", Teiserver.Logging.Tasks.PersistServerQuarterTask},
       {"5 9 * * *", Teiserver.Logging.Tasks.PersistServerYearTask},
       {"6 9 * * *", Teiserver.Logging.Tasks.PersistMatchDayTask},
       {"7 9 * * *", Teiserver.Logging.Tasks.PersistMatchMonthTask},
       {"8 9 * * *", Teiserver.Telemetry.InfologCleanupTask},
       {"9 9 * * *", Teiserver.Logging.Tasks.PersistUserActivityDayTask},

       # 9:43
       {"43 9 * * *", Teiserver.Game.AchievementCleanupTask},

       # 0302 and 1202 every day, gives time for multiple telemetry day tasks to run if needed
       {"2 3 * * *", Teiserver.Account.RecalculateUserDailyStatTask},
       {"2 12 * * *", Teiserver.Account.RecalculateUserDailyStatTask}
     ]}
  ],
  queues: [logging: 1, cleanup: 1, teiserver: 10]

config :teiserver, :time_zone_database, Tzdata.TimeZoneDatabase

config :xema, loader: Teiserver.Tachyon.SchemaLoader

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
