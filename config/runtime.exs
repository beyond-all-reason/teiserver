import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Sensitive values should be passed through the environment. An example
# EnvironmentFile that can be used with systemd is under
# documents/prod_files/example-environment-file

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/teiserver start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if Teiserver.ConfigHelpers.get_env("PHX_SERVER", nil) do
  config :teiserver, TeiserverWeb.Endpoint, server: true
end

# Only do some runtime configuration in production since in dev and tests the
# files are automatically recompiled on the fly and thus, config/{dev,test}.exs
# are just fine
if config_env() == :prod do
  # used for mailing, checking origins, finding tls certs…
  domain_name = Teiserver.ConfigHelpers.get_env("DOMAIN_NAME", "beyondallreason.info")

  certificates = [
    keyfile: Teiserver.ConfigHelpers.get_env("TLS_PRIVATE_KEY_PATH"),
    certfile: Teiserver.ConfigHelpers.get_env("TLS_CERT_PATH"),
    cacertfile: Teiserver.ConfigHelpers.get_env("TLS_CA_CERT_PATH")
  ]

  # this is used in lib/teiserver_web/controllers/account/setup_controller.ex
  # as a special endpoint to create the root user. Setting it to empty or nil
  # will disable the functionality completely.
  # There is already a root user, so disable it
  config :teiserver, Teiserver.Setup, key: nil

  config :teiserver, Teiserver,
    game_name: "Beyond All Reason",
    game_name_short: "BAR",
    main_website: "https://www.beyondallreason.info/",
    privacy_email: "privacy@beyondallreason.info",
    discord: "https://discord.gg/beyond-all-reason",
    certs: certificates,
    website: [
      url: "beyondallreason.info"
    ],
    server_flag: "GB-WLS",
    enable_benchmark: false,
    node_name: Teiserver.ConfigHelpers.get_env("NODE_NAME"),
    extra_logging: false,
    enable_managed_lobbies: true,
    user_agreement:
      "A verification code has been sent to your email address. Please read our terms of service at https://#{domain_name}/privacy_policy and the code of conduct at https://www.beyondallreason.info/code-of-conduct. Then enter your six digit code below if you agree to the terms."

  config :teiserver, Teiserver.Repo,
    username: Teiserver.ConfigHelpers.get_env("DB_USERNAME"),
    password: Teiserver.ConfigHelpers.get_env("DB_PASSWORD"),
    database: Teiserver.ConfigHelpers.get_env("DB_NAME"),
    pool_size: 40,
    timeout: 120_000,
    queue_interval: 2000

  check_origin =
    if Teiserver.ConfigHelpers.get_env("SHOULD_CHECK_ORIGIN", false, :bool) do
      ["//#{domain_name}", "//*.#{domain_name}"]
    else
      false
    end

  config :teiserver, TeiserverWeb.Endpoint,
    url: [host: domain_name],
    check_origin: check_origin,
    https:
      certificates ++
        [
          versions: [:"tlsv1.2"],
          # dhfile is not supported for tls 1.3
          # https://www.erlang.org/doc/man/ssl.html#type-dh_file
          dhfile: Teiserver.ConfigHelpers.get_env("TLS_DH_FILE_PATH", "/etc/ssl/dhparam.pem")
        ],
    http: [:inet6, port: Teiserver.ConfigHelpers.get_env("PORT", "4000", :int)],
    secret_key_base: Teiserver.ConfigHelpers.get_env("HTTP_SECRET_KEY_BASE")

  config :teiserver, Teiserver.Account.Guardian,
    issuer: Teiserver.ConfigHelpers.get_env("GUARDIAN_ISSUER", "teiserver"),
    secret_key: Teiserver.ConfigHelpers.get_env("GUARDIAN_SECRET_KEY")


  config :teiserver, Teiserver.Mailer,
    adapter: Bamboo.SMTPAdapter,
    contact_address:
      Teiserver.ConfigHelpers.get_env("CONTACT_EMAIL_ADDRESS", "info@#{domain_name}"),
    noreply_name: "Beyond All Reason",
    noreply_address:
      Teiserver.ConfigHelpers.get_env("NOREPLY_EMAIL_ADDRESS", "noreply@#{domain_name}"),
    smtp_server: Teiserver.ConfigHelpers.get_env("SMTP_SERVER"),
    hostname: Teiserver.ConfigHelpers.get_env("SMTP_HOSTNAME"),
    # port: 1025,
    port: Teiserver.ConfigHelpers.get_env("SMTP_PORT", "587", :int),
    username: Teiserver.ConfigHelpers.get_env("SMTP_USERNAME"),
    password: Teiserver.ConfigHelpers.get_env("SMTP_PASSWORD"),
    # tls: :if_available, # can be `:always` or `:never`
    # can be `:always` or `:never`
    tls: :always,
    tls_verify:
      if(Teiserver.ConfigHelpers.get_env("SMTP_TLS_VERIFY", true, :bool),
        do: :verify_peer,
        else: :verify_none
      ),
    # or {":system", ALLOWED_TLS_VERSIONS"} w/ comma seprated values (e.g. "tlsv1.1,tlsv1.2")
    allowed_tls_versions: [:"tlsv1.2"],
    # can be `true`
    no_mx_lookups: false,
    # auth: :if_available # can be `always`. If your smtp relay requires authentication set it to `always`.
    auth: :always

  log_root_path = Teiserver.ConfigHelpers.get_env("LOG_ROOT_PATH", "/var/log/teiserver/")

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
