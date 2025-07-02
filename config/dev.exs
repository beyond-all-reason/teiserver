import Config

config :teiserver, Teiserver.Setup, key: "dev_key"

# Configure your database
config :teiserver, Teiserver.Repo,
  username: System.get_env("TEI_DB_USERNAME") || "teiserver_dev",
  password: System.get_env("TEI_DB_PASSWORD") || "123456789",
  database: System.get_env("TEI_DB_NAME") || "teiserver_dev",
  hostname: System.get_env("TEI_DB_HOSTNAME") || "localhost",
  port:     String.to_integer(System.get_env("TEI_DB_PORT") || "5432"),
  show_sensitive_data_on_connection_error: true,
  pool_size: 10,
  timeout: 180_000


# Helper function to set the bind_ip for the container
# Fallback to the original value if not set
bind_ip =
  (System.get_env("TEI_BIND_IP") || "127.0.0.1")
  |> String.split(".")
  |> Enum.map(&String.to_integer/1)
  |> List.to_tuple()

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with webpack to recompile .js and .css sources.
config :teiserver, TeiserverWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  watchers: [
    # Start the esbuild watcher by calling Esbuild.install_and_run(:default, args)
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
    dark_sass: {
      DartSass,
      :install_and_run,
      [:dark, ~w(--embed-source-map --source-map-urls=absolute --watch)]
    },
    server: true,
    light_sass: {
      DartSass,
      :install_and_run,
      [:light, ~w(--embed-source-map --source-map-urls=absolute --watch)]
    }
  ]

config :dart_sass,
  version: "1.61.0",
  light: [
    args: ~w(scss/light.scss ../priv/static/assets/light.css),
    cd: Path.expand("../assets", __DIR__)
  ],
  dark: [
    args: ~w(scss/dark.scss ../priv/static/assets/dark.css),
    cd: Path.expand("../assets", __DIR__)
  ]

config :teiserver, Teiserver,
  certs: [
    keyfile: "priv/certs/localhost.key",
    certfile: "priv/certs/localhost.crt",
    cacertfile: "priv/certs/localhost.crt"
  ],
  ports: [
    tcp: 8200,
    tls: 8201
  ],
  heartbeat_interval: nil,
  heartbeat_timeout: nil,
  enable_discord_bridge: false,
  accept_all_emails: true

# Watch static and templates for browser reloading.
config :teiserver, TeiserverWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/teiserver_web/(controllers|live|components|live_components|views|templates)/.*(ex|heex)$"
    ]
  ]

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Comment the below block to allow background jobs to happen in dev
config :teiserver, Oban,
  queues: false,
  crontab: false

try do
  import_config "dev.secret.exs"
rescue
  _ in File.Error ->
    nil

  error ->
    reraise error, __STACKTRACE__
end
