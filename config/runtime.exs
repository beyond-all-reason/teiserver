import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/teiserver start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :teiserver, TeiserverWeb.Endpoint, server: true
end

# Only do some runtime configuration in production since in dev and tests the
# files are automatically recompiled on the fly and thus, config/{dev,test}.exs
# are just fine
if config_env() == :prod do
  # used for mailing, checking origins, finding tls certs…
  domain_name = System.get_env("DOMAIN_NAME", "beyondallreason.info")

  certificates = [
    keyfile: System.fetch_env!("TLS_PRIVATE_KEY_PATH"),
    certfile: System.fetch_env!("TLS_CERT_PATH"),
    cacertfile: System.fetch_env!("TLS_CA_CERT_PATH")
  ]

  # this is used in lib/teiserver_web/controllers/account/setup_controller.ex
  # as a special endpoint to create the root user. Setting it to empty or nil
  # will disable the functionality completely.
  # There is already a root user, so disable it
  config :teiserver, Teiserver.Setup, key: nil

  config :teiserver, Teiserver,
    game_name: "Beyond all reason",
    game_name_short: "BAR",
    main_website: "https://www.beyondallreason.info/",
    privacy_email: "privacy@beyondallreason.info",
    discord: System.get_env("DISCORD_LINK"),
    certs: certificates,
    enable_benchmark: false,
    node_name: System.fetch_env!("NODE_NAME"),
    enable_managed_lobbies: true,
    tachyon_schema_path: "/apps/teiserver/lib/teiserver-0.1.0/priv/tachyon/schema_v1/*/*/*.json"

  config :teiserver, Teiserver.Repo,
    username: System.fetch_env!("DB_USERNAME"),
    password: System.fetch_env!("DB_PASSWORD"),
    database: System.fetch_env!("DB_NAME"),
    pool_size: 40,
    timeout: 120_000,
    queue_interval: 2000

  config :teiserver, TeiserverWeb.Endpoint,
    url: [host: domain_name],
    check_origin: ["//#{domain_name}", "//*.#{domain_name}"],
    https:
      certificates ++
        [
          versions: [:"tlsv1.2"],
          # dhfile is not supported for tls 1.3
          # https://www.erlang.org/doc/man/ssl.html#type-dh_file
          dhfile: System.fetch_env!("TLS_DH_FILE_PATH")
        ],
    http: [:inet6, port: String.to_integer(System.get_env("PORT", "4000"))],
    secret_key_base: System.fetch_env!("HTTP_SECRET_KEY_BASE")

  config :teiserver, Teiserver.Account.Guardian,
    issuer: System.fetch_env!("GUARDIAN_ISSUER"),
    secret_key: System.fetch_env!("GUARDIAN_SECRET_KEY")

  config :teiserver, Teiserver.Mailer,
    noreply_address: "noreply@#{domain_name}",
    contact_address: "info@#{domain_name}",
    noreply_name: "Beyond all reason team",
    adapter: Bamboo.SMTPAdapter,
    server: System.fetch_env!("MAILER_SERVER"),
    hostname: domain_name,
    # port: 1025,
    port: String.to_integer(System.get_env("MAILER_PORT", "587")),
    # or {:system, "SMTP_USERNAME"}
    username: System.get_env("MAILER_USERNAME", "noreply@#{domain_name}"),
    # or {:system, "SMTP_PASSWORD"}
    password: System.fetch_env!("MAILER_PASSWORD"),
    # tls: :if_available, # can be `:always` or `:never`
    # can be `:always` or `:never`
    tls: :always,
    # or {":system", ALLOWED_TLS_VERSIONS"} w/ comma seprated values (e.g. "tlsv1.1,tlsv1.2")
    allowed_tls_versions: [:tlsv1, :"tlsv1.1", :"tlsv1.2"],
    # can be `true`
    ssl: false,
    retries: 1,
    # can be `true`
    no_mx_lookups: false,
    # auth: :if_available # can be `always`. If your smtp relay requires authentication set it to `always`.
    auth: :always

  log_root_path = System.fetch_env("LOG_ROOT_PATH", "/var/log/teiserver/")

  config :logger,
    backends: [
      {LoggerFileBackend, :error_log},
      {LoggerFileBackend, :notice_log},
      {LoggerFileBackend, :info_log},
      :console
    ]

  # Do not print debug messages in production
  config :logger,
    format: "$date $time [$level] $metadata $message\n",
    metadata: [:request_id, :user_id],
    level: :info

  config :logger, :error_log,
    path: "#{log_root_path}error.log",
    format: "$date $time [$level] $metadata $message\n",
    metadata: [:request_id, :user_id],
    level: :error

  config :logger, :notice_log,
    path: "#{log_root_path}notice.log",
    format: "$date $time [$level] $metadata $message\n",
    metadata: [:request_id, :user_id],
    level: :notice

  config :logger, :info_log,
    path: "#{log_root_path}info.log",
    format: "$date $time [$level] $metadata $message\n",
    metadata: [:request_id, :user_id],
    level: :info
end
