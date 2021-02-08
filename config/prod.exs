use Mix.Config

config :logger, :error_log,
  path: "/var/log/teiserver.log",
  level: :error
