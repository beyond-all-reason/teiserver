import Config

# This makes anything in our tests involving user passwords (creating or logging in) much faster
config :argon2_elixir, t_cost: 1, m_cost: 8

# Configure your database
config :teiserver, Teiserver.Repo,
  username: "teiserver_test",
  password: "123456789",
  database: "teiserver_test",
  hostname: "localhost",
  queue_target: 5000,
  queue_interval: 100_000,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 50,
  timeout: 300_000

config :teiserver, Teiserver.SpringTcpServer,
  # Don't start listeners at startup, we'll start manually
  disable_startup: true,
  # Set port 0 to allow concurrent servers (uses random port for each new child)
  listeners: [
    tcp: [socket_opts: [port: 0]],
    tls: [socket_opts: [port: 0]]
  ]

config :teiserver, Teiserver,
  certs: [
    keyfile: "priv/certs/localhost.key",
    certfile: "priv/certs/localhost.crt",
    cacertfile: "priv/certs/localhost.crt"
  ],
  test_mode: true,
  enable_hooks: false,
  enable_coordinator_mode: false,
  enable_accolade_mode: false,
  enable_discord_bridge: false,
  enable_match_monitor: false,
  post_login_delay: 0,
  spring_post_state_change_delay: 0,
  automod_delay: 1_000,
  user_agreement: "User agreement goes here."

config :teiserver, DiscordBridgeBot,
  token: nil,
  bot_name: "Teiserver Bridge TEST",
  bridges: [
    {"bridge_test_room", nil}
  ]

config :teiserver, TeiserverWeb.Endpoint,
  url: [host: "localhost"],
  http: [port: 4002],
  # We don't spawn the https endpoint in test
  https: nil,
  # Spawn a real server. This is required for websocket upgrade since it
  # doesn't work with the test Plug.Conn used for "regular" http requests
  server: true

config :teiserver, Teiserver.OAuth, issuer: "http://localhost:4002"

# Print only warnings and errors during test
config :logger, level: :warning

config :teiserver, Oban, testing: :manual
# queues: false,
# plugins: false,
# crontab: false

config :teiserver, Teiserver.Mailer,
  adapter: Bamboo.TestAdapter,
  noreply_address: "noreply@testsite.co.uk",
  contact_address: "info@testsite.co.uk"
