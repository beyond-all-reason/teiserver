import Config

config :iex,
  ansi_enabled: true

config :teiserver, Barserver,
  site_title: "BAR",
  site_suffix: "",
  site_description: "",
  site_icon: "fa-duotone fa-robot",
  credit: "Teifion Jordan"

# Default configs
config :teiserver, Barserver.Config,
  defaults: %{
    tz: "UTC"
  }

config :teiserver,
  ecto_repos: [Barserver.Repo]

# Configures the endpoint
config :teiserver, BarserverWeb.Endpoint,
  url: [host: "localhost"],
  # This is overriden in your secret config, it's here only to allow things to run easily
  secret_key_base: "6FN12Jv4ZITAK1fq7ehD0MTRvbLsXYWj+wLY3ifkzzlcUIcpUJK7aG/ptrJSemAy",
  live_view: [signing_salt: "wZVVigZo"],
  render_errors: [
    formats: [html: BarserverWeb.ErrorHTML, json: BarserverWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Barserver.PubSub

config :esbuild,
  version: "0.14.41",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2016 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :teiserver, Barserver,
  ports: [
    tcp: 8200,
    tls: 8201,
    tachyon: 8202
  ],
  website: [
    url: "mywebsite.com"
  ],
  enable_benchmark: false,
  enable_hooks: true,
  tachyon_schema_path: "priv/tachyon/schema_v1/*/*/*.json",

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
  default_spring_protocol: Barserver.Protocols.Spring,
  default_tachyon_protocol: Barserver.Protocols.Tachyon.V1.Tachyon,
  github_repo: "https://github.com/beyond-all-reason/teiserver",
  enable_discord_bridge: false,
  enable_coordinator_mode: true,
  enable_managed_lobbies: false,
  enable_accolade_mode: true,
  enable_match_monitor: true,
  enable_hailstorm: false,
  bot_email_domain: "teiserver",
  user_agreement: "User agreement goes here.",
  server_flag: "GB",
  post_login_delay: 150,
  spring_post_state_change_delay: 150,
  user_agreement:
    "A verification code has been sent to your email address. Please read our terms of service at <<<site_url>>> and the code of conduct at <<<URL>>>. Then enter your six digit code below if you agree to the terms.",
  accept_all_emails: false,
  retention: %{
    telemetry_infolog: 14,
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

config :logger, :console,
  format: "$date $time $metadata[$level] $message\n",
  metadata: [:request_id, :user_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# This secret key is overwritten in prod.secret.exs
config :teiserver, Barserver.Account.Guardian,
  issuer: "teiserver",
  # This is overriden in your secret config, it's here only to allow things to run easily
  secret_key: "9vJcJOYwsjdIQ9IhfOI5F9GQMykuNjBW58FY9S/TqMsq6gRdKgY05jscQAFVKfwa",
  ttl: {30, :days}

config :teiserver, Oban,
  repo: Barserver.Repo,
  plugins: [
    {Oban.Plugins.Pruner, max_age: 3600},
    {Oban.Plugins.Cron,
     crontab: [
       # Every hour
       {"0 * * * *", Barserver.Admin.HourlyCleanupTask},

       # Every day at 1am
       {"0 1 * * *", Barserver.Admin.DailyCleanupTask},

       # Every day at 2am
       {"0 2 * * *", Barserver.Logging.AggregateViewLogsTask},

       # 1:07 am
       {"7 1 * * *", Barserver.Account.Tasks.DailyCleanupTask},
       {"22 1 * * *", Barserver.Telemetry.EventCleanupTask},

       # At 17 minutes past every hour
       {"17 * * * *", Barserver.Battle.Tasks.CleanupTask},

       # Every minute
       {"* * * * *", Barserver.Logging.Tasks.PersistServerMinuteTask},
       {"* * * * *", Barserver.Moderation.RefreshUserRestrictionsTask},

       # Every minute
       {"* * * * *", Barserver.Battle.Tasks.PostMatchProcessTask},

       # 2am
       {"1 2 * * *", Barserver.Logging.Tasks.PersistServerDayTask},
       {"2 2 * * *", Barserver.Logging.Tasks.PersistServerWeekTask},
       {"3 2 * * *", Barserver.Logging.Tasks.PersistServerMonthTask},
       {"4 2 * * *", Barserver.Logging.Tasks.PersistServerQuarterTask},
       {"5 2 * * *", Barserver.Logging.Tasks.PersistServerYearTask},
       {"6 2 * * *", Barserver.Logging.Tasks.PersistMatchDayTask},
       {"7 2 * * *", Barserver.Logging.Tasks.PersistMatchMonthTask},
       {"8 2 * * *", Barserver.Telemetry.InfologCleanupTask},
       {"9 2 * * *", Barserver.Logging.Tasks.PersistUserActivityDayTask},

       # 2:43
       {"43 2 * * *", Barserver.Game.AchievementCleanupTask},

       # 0302 and 1202 every day, gives time for multiple telemetry day tasks to run if needed
       {"2 3 * * *", Barserver.Account.RecalculateUserDailyStatTask},
       {"2 12 * * *", Barserver.Account.RecalculateUserDailyStatTask}
     ]}
  ],
  queues: [logging: 1, cleanup: 1, teiserver: 10]

config :teiserver, :time_zone_database, Tzdata.TimeZoneDatabase

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
