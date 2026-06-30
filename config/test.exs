alias Teiserver.ConfigHelpers

import Config

# This makes anything in our tests involving user passwords (creating or logging in) much faster
config :argon2_elixir, t_cost: 1, m_cost: 8

partition = System.get_env("MIX_TEST_PARTITION", "0") |> String.to_integer()
partition_port = partition * 100
# <> partition
database_url = "postgresql://teiserver_test:123456789@localhost:5432/teiserver_test"

# Configure your database
config :teiserver, Teiserver.Repo,
  url: database_url,
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
  user_agreement: "User agreement goes here.",
  require_mfa_for_privileged_roles: false

config :teiserver, DiscordBridgeBot,
  token: nil,
  bot_name: "Teiserver Bridge TEST",
  bridges: [
    {"bridge_test_room", nil}
  ]

raw_http_port = System.get_env("TEISERVER_HTTP_PORT", "4002") |> String.to_integer()
http_port = raw_http_port + partition_port

config :teiserver, TeiserverWeb.Endpoint,
  url: [host: "localhost"],
  http: [port: http_port],
  # We don't spawn the https endpoint in test
  https: nil,
  # Spawn a real server. This is required for websocket upgrade since it
  # doesn't work with the test Plug.Conn used for "regular" http requests
  server: true

config :teiserver, Teiserver.OAuth, issuer: "http://localhost:#{http_port}"

metrics_port_raw = System.get_env("TEI_METRICS_SERVER_PORT", "4001") |> String.to_integer()
metrics_port = metrics_port_raw + partition_port

config :teiserver, TeiserverWeb.Monitoring, port: metrics_port

# Print only warnings and errors during test
config :logger, level: :warning

config :teiserver, Oban,
  testing: :manual,
  queues: false,
  plugins: false,
  crontab: false

config :teiserver, Teiserver.PromEx, disabled: true

config :teiserver, Teiserver.IpCheck, client_module: Teiserver.IpCheck.Stub

config :teiserver, Teiserver.Mailer,
  adapter: Swoosh.Adapters.Test,
  noreply_address: "noreply@testsite.co.uk",
  contact_address: "info@testsite.co.uk"
