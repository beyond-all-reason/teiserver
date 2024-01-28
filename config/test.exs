import Config

# This makes anything in our tests involving user passwords (creating or logging in) much faster
config :argon2_elixir, t_cost: 1, m_cost: 8

# Configure your database
config :teiserver, Barserver.Repo,
  username: "barserver_test",
  password: "123456789",
  database: "barserver_test",
  hostname: "localhost",
  queue_target: 5000,
  queue_interval: 100_000,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 50,
  timeout: 300_000

config :teiserver, Barserver,
  certs: [
    keyfile: "priv/certs/localhost.key",
    certfile: "priv/certs/localhost.crt",
    cacertfile: "priv/certs/localhost.crt"
  ],
  ports: [
    tcp: 9200,
    tls: 9201,
    tachyon: 9202
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
  bot_name: "Barserver Bridge TEST",
  bridges: [
    {"bridge_test_room", nil}
  ]

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :teiserver, BarserverWeb.Endpoint,
  http: [port: 4002],
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

config :teiserver, Oban, testing: :manual
# queues: false,
# plugins: false,
# crontab: false

config :teiserver, Barserver.Mailer,
  adapter: Bamboo.TestAdapter,
  noreply_address: "noreply@testsite.co.uk",
  contact_address: "info@testsite.co.uk"


try do
  import_config "test.secret.exs"
rescue
  _ in File.Error ->
    nil

  error ->
    reraise error, __STACKTRACE__
end
