import Config

config :teiserver, Teiserver.Repo,
  pool_size: 40,
  timeout: 120_000,
  queue_interval: 2000

config :logger, :default_handler, level: :info

# disable stdout logging in production, rely on log files
config :logger, LoggerBackends.Console, false
