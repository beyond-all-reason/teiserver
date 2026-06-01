import Config

config :teiserver, Teiserver.Repo,
  pool_size: 40,
  timeout: 120_000,
  queue_interval: 2000

config :logger, :default_handler, level: :info

config :teiserver, :logger, [
  {:handler, :json_log, :logger_std_h,
   %{
     # different handler, so needs its own level config
     level: :info,
     # domain can be `elixir` or `otp`. It's not super important and the source
     # is usually easy to identify with the other metadata + message
     formatter: {LoggerJSON.Formatters.Basic, metadata: {:all_except, [:domain]}}
   }}
]

# disable the default stdout handler, there are log files and
# the json logger (on stdout)
config :logger, :default_handler, false
