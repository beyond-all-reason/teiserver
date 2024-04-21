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



end
