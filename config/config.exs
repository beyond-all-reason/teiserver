use Mix.Config

config :central,
  ecto_repos: [Central.Repo]

# Configures the endpoint
config :central, CentralWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "6FN12Jv4ZITAK1fq7ehD0MTRvbLsXYWj+wLY3ifkzzlcUIcpUJK7aG/ptrJSemAy",
  live_view: [signing_salt: "wZVVigZo"],
  render_errors: [view: CentralWeb.ErrorView, accepts: ~w(html json)],
  pubsub_server: Central.PubSub

config :central, Teiserver,
  ports: [
    tcp: 8200,
    tls: 8201
  ]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# This secret key is overwritten in prod.secret.exs
config :central, Central.Account.Guardian,
  issuer: "central",
  secret_key: "8vJcJOYwsjdIQ9IhfOI5F9GQMykuNjBW58FY9S/TqMsq6gRdKgY05jscQAFVKfwa",
  ttl: {30, :days}

config :central, Central.General.LoadTestServer, enable_loadtest: false

config :central, Central.Communication.BlogFile, save_path: "/etc/central/blog_files"

config :central, Oban,
  repo: Central.Repo,
  plugins: [{Oban.Plugins.Pruner, max_age: 3600}],
  queues: [logging: 1],
  crontab: [
    # Every day at 2am
    {"0 2 * * *", Central.Logging.AggregateViewLogsTask}
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
