import Config

config :logger, :default_handler, level: :info

# disable stdout logging in production, rely on log files
config :logger, LoggerBackends.Console, false
