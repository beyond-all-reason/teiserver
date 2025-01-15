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

# used for mailing, checking origins, finding tls certs…
domain_name = Teiserver.ConfigHelpers.get_env("TEI_DOMAIN_NAME", "beyondallreason.info")

# Only do some runtime configuration in production since in dev and tests the
# files are automatically recompiled on the fly and thus, config/{dev,test}.exs
# are just fine
if config_env() == :prod do
  certificates = [
    keyfile: Teiserver.ConfigHelpers.get_env("TEI_TLS_PRIVATE_KEY_PATH"),
    certfile: Teiserver.ConfigHelpers.get_env("TEI_TLS_CERT_PATH"),
    cacertfile: Teiserver.ConfigHelpers.get_env("TEI_TLS_CA_CERT_PATH")
  ]

  # this is used in lib/teiserver_web/controllers/account/setup_controller.ex
  # as a special endpoint to create the root user. Setting it to empty or nil
  # will disable the functionality completely.
  config :teiserver, Teiserver.Setup,
    key: Teiserver.ConfigHelpers.get_env("TEI_SETUP_ROOT_KEY", nil)

  enable_discord_bridge =
    Teiserver.ConfigHelpers.get_env("TEI_ENABLE_DISCORD_BRIDGE", true, :bool)

  config :teiserver, Teiserver,
    game_name: "Beyond All Reason",
    game_name_short: "BAR",
    main_website: "https://www.beyondallreason.info/",
    privacy_email: "privacy@beyondallreason.info",
    discord: "https://discord.gg/beyond-all-reason",
    enable_discord_bridge: enable_discord_bridge,
    ports: [
      tcp: Teiserver.ConfigHelpers.get_env("TEI_SPRING_TCP_PORT", 8200, :int),
      tls: Teiserver.ConfigHelpers.get_env("TEI_SPRING_TLS_PORT", 8201, :int)
    ],
    certs: certificates,
    website: [
      url: "beyondallreason.info"
    ],
    server_flag: "GB-WLS",
    enable_benchmark: false,
    node_name: Teiserver.ConfigHelpers.get_env("TEI_NODE_NAME"),
    enable_managed_lobbies: true,
    user_agreement:
      "A verification code has been sent to your email address. Please read our terms of service at https://#{domain_name}/privacy_policy and the code of conduct at https://www.beyondallreason.info/code-of-conduct. Then enter your six digit code below if you agree to the terms."

  config :teiserver, Teiserver.Repo,
    hostname: Teiserver.ConfigHelpers.get_env("TEI_DB_HOSTNAME"),
    username: Teiserver.ConfigHelpers.get_env("TEI_DB_USERNAME"),
    password: Teiserver.ConfigHelpers.get_env("TEI_DB_PASSWORD"),
    database: Teiserver.ConfigHelpers.get_env("TEI_DB_NAME"),
    pool_size: 40,
    timeout: 120_000,
    queue_interval: 2000

  check_origin =
    if Teiserver.ConfigHelpers.get_env("TEI_SHOULD_CHECK_ORIGIN", false, :bool) do
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
          dhfile: Teiserver.ConfigHelpers.get_env("TEI_TLS_DH_FILE_PATH", "/etc/ssl/dhparam.pem")
        ],
    http: [:inet6, port: Teiserver.ConfigHelpers.get_env("TEI_PORT", "4000", :int)],
    secret_key_base: Teiserver.ConfigHelpers.get_env("TEI_HTTP_SECRET_KEY_BASE")

  config :teiserver, Teiserver.Account.Guardian,
    issuer: Teiserver.ConfigHelpers.get_env("TEI_GUARDIAN_ISSUER", "teiserver"),
    secret_key: Teiserver.ConfigHelpers.get_env("TEI_GUARDIAN_SECRET_KEY")

  config :teiserver, Teiserver.OAuth, issuer: "https://#{domain_name}"

  if Teiserver.ConfigHelpers.get_env("TEI_ENABLE_EMAIL_INTEGRATION", true, :bool) do
    config :teiserver, Teiserver.Mailer,
      adapter: Bamboo.SMTPAdapter,
      contact_address:
        Teiserver.ConfigHelpers.get_env("TEI_CONTACT_EMAIL_ADDRESS", "info@#{domain_name}"),
      noreply_name: "Beyond All Reason",
      noreply_address:
        Teiserver.ConfigHelpers.get_env("TEI_NOREPLY_EMAIL_ADDRESS", "noreply@#{domain_name}"),
      server: Teiserver.ConfigHelpers.get_env("TEI_SMTP_SERVER"),
      hostname: Teiserver.ConfigHelpers.get_env("TEI_SMTP_HOSTNAME"),
      # port: 1025,
      port: Teiserver.ConfigHelpers.get_env("TEI_SMTP_PORT", "587", :int),
      username: Teiserver.ConfigHelpers.get_env("TEI_SMTP_USERNAME"),
      password: Teiserver.ConfigHelpers.get_env("TEI_SMTP_PASSWORD"),
      # tls: :if_available, # can be `:always` or `:never`
      # can be `:always` or `:never`
      tls: :always,
      tls_verify:
        if(Teiserver.ConfigHelpers.get_env("TEI_SMTP_TLS_VERIFY", true, :bool),
          do: :verify_peer,
          else: :verify_none
        ),
      # or {":system", ALLOWED_TLS_VERSIONS"} w/ comma seprated values (e.g. "tlsv1.1,tlsv1.2")
      allowed_tls_versions: [:"tlsv1.2"],
      # can be `true`
      no_mx_lookups: false,
      # auth: :if_available # can be `always`. If your smtp relay requires authentication set it to `always`.
      auth: :always
  end

  log_root_path = Teiserver.ConfigHelpers.get_env("TEI_LOG_ROOT_PATH", "/var/log/teiserver/")

  config :logger,
    backends: [
      {LoggerFileBackend, :error_log},
      {LoggerFileBackend, :notice_log},
      {LoggerFileBackend, :info_log},
      :console
    ]

  # Do not print debug messages in production
  config :logger, :default_handler, false

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

  if enable_discord_bridge do
    config :nostrum,
      gateway_intents: [
        :guilds,
        :guild_messages,
        :guild_message_reactions,
        :direct_messages,
        :message_content,
        :direct_message_reactions
      ],
      log_full_events: true,
      log_dispatch_events: true,
      token: Teiserver.ConfigHelpers.get_env("TEI_DISCORD_BOT_TOKEN")

    config :teiserver, Teiserver.Bridge.DiscordBridgeBot,
      token: Teiserver.ConfigHelpers.get_env("TEI_DISCORD_BOT_TOKEN"),
      guild_id: Teiserver.ConfigHelpers.get_env("TEI_DISCORD_GUILD_ID"),
      bot_name: Teiserver.ConfigHelpers.get_env("TEI_DISCORD_BOT_NAME")
  end
end
