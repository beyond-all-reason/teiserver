use Mix.Config

# Configure your database
config :central, Central.Repo,
  username: "postgres",
  password: "postgres",
  database: "teiserver_test",
  hostname: "localhost",
  timeout: 120_000,
  queue_target: 5000,
  queue_interval: 100_000,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 50

config :central, Teiserver,
  certs: [
    keyfile: "priv/certs/localhost.key",
    certfile: "priv/certs/localhost.crt",
    cacertfile: "priv/certs/localhost.crt"
  ],
  enable_hooks: false,
  enable_coordinator_mode: false,
  enable_discord_bridge: false,
  enable_match_monitor: false,
  post_login_delay: 0,
  spring_post_state_change_delay: 0,
  user_agreement: "User agreement goes here."

config :central, DiscordBridge,
  token: nil,
  bot_name: "Teiserver Bridge TEST",
  bridges: [
    {"bridge_test_room", nil}
  ]

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :central, CentralWeb.Endpoint,
  http: [port: 4002],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

config :central, Oban,
  queues: false,
  plugins: false,
  crontab: false

config :central, Central.Mailer, adapter: Swoosh.Adapters.Test
