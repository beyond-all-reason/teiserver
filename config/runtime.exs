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

# this is used in lib/teiserver_web/controllers/account/setup_controller.ex
# as a special endpoint to create the root user. Setting it to empty or nil
# will disable the functionality completely.
config :teiserver, Teiserver.Setup,
  key: Teiserver.ConfigHelpers.get_env("TEI_SETUP_ROOT_KEY", nil)

config :teiserver,
  blog_allow_upload: Teiserver.ConfigHelpers.get_env("TEI_BLOG_ALLOW_UPLOAD", false, :bool),
  blog_upload_path: System.get_env("TEI_BLOG_UPLOAD_PATH"),
  blog_upload_extensions:
    System.get_env("TEI_BLOG_UPLOAD_EXTENSIONS", ".jpg .jpeg .png") |> String.split(" "),
  argon2_salt: Teiserver.ConfigHelpers.get_env("TEI_ARGON2_SALT", "default_salt_value_goes_Here")

config :teiserver, Teiserver,
  game_name: "Beyond All Reason",
  game_name_short: "BAR",
  main_website: "https://www.beyondallreason.info/",
  privacy_email: "privacy@beyondallreason.info",
  website: [
    url: "beyondallreason.info"
  ],
  server_flag: "GB-WLS",
  enable_benchmark: false,
  node_name: Teiserver.ConfigHelpers.get_env("TEI_NODE_NAME", "local"),
  enable_managed_lobbies: true,
  user_agreement:
    Application.get_env(:teiserver, Teiserver)[:user_agreement] ||
      "A verification code has been sent to your email address. Please read our terms of service at https://#{domain_name}/privacy_policy and the code of conduct at https://www.beyondallreason.info/code-of-conduct. Then enter your six digit code below if you agree to the terms."

repo_env = Application.get_env(:teiserver, Teiserver.Repo)

config :teiserver, Teiserver.Repo,
  hostname: Teiserver.ConfigHelpers.get_env("TEI_DB_HOSTNAME", repo_env[:hostname]),
  username: Teiserver.ConfigHelpers.get_env("TEI_DB_USERNAME", repo_env[:username]),
  password: Teiserver.ConfigHelpers.get_env("TEI_DB_PASSWORD", repo_env[:password]),
  database: Teiserver.ConfigHelpers.get_env("TEI_DB_NAME", repo_env[:database]),
  pool_size: Teiserver.ConfigHelpers.get_env("TEI_DB_POOL_SIZE", repo_env[:pool_size], :int),
  timeout: Teiserver.ConfigHelpers.get_env("TEI_DB_TIMEOUT", repo_env[:timeout], :int),
  queue_interval:
    Teiserver.ConfigHelpers.get_env("TEI_DB_QUEUE_INTERVAL", repo_env[:queue_interval], :int)

check_origin =
  if Teiserver.ConfigHelpers.get_env("TEI_SHOULD_CHECK_ORIGIN", false, :bool) do
    ["//#{domain_name}", "//*.#{domain_name}"]
  else
    false
  end

endpoint_defaults = Application.get_env(:teiserver, TeiserverWeb.Endpoint)

config :teiserver, TeiserverWeb.Endpoint,
  url: [host: endpoint_defaults[:url][:host] || domain_name],
  check_origin: check_origin,
  http: [
    :inet6,
    port:
      Teiserver.ConfigHelpers.get_env(
        "TEI_PORT",
        endpoint_defaults[:http][:port] || 4000,
        :int
      )
  ],
  # the default is meant for ease of local dev
  secret_key_base:
    Teiserver.ConfigHelpers.get_env(
      "TEI_HTTP_SECRET_KEY_BASE",
      endpoint_defaults[:secret_key_base]
    )

use_tls? = Teiserver.ConfigHelpers.get_env("TEI_TLS_PRIVATE_KEY_PATH", nil) != nil
config :teiserver, Teiserver, use_tls?: use_tls?

tei_defaults = Application.get_env(:teiserver, Teiserver)

if use_tls? do
  certificates = [
    keyfile: Teiserver.ConfigHelpers.get_env("TEI_TLS_PRIVATE_KEY_PATH"),
    certfile: Teiserver.ConfigHelpers.get_env("TEI_TLS_CERT_PATH"),
    cacertfile: Teiserver.ConfigHelpers.get_env("TEI_TLS_CA_CERT_PATH")
  ]

  config :teiserver, Teiserver,
    ports: [
      tcp:
        Teiserver.ConfigHelpers.get_env("TEI_SPRING_TCP_PORT", tei_defaults[:ports][:tcp], :int),
      tls:
        Teiserver.ConfigHelpers.get_env("TEI_SPRING_TLS_PORT", tei_defaults[:ports][:tls], :int)
    ],
    certs: certificates

  config :teiserver, TeiserverWeb.Endpoint,
    https:
      certificates ++
        [
          versions: [:"tlsv1.2"],
          # dhfile is not supported for tls 1.3
          # https://www.erlang.org/doc/man/ssl.html#type-dh_file
          dhfile: Teiserver.ConfigHelpers.get_env("TEI_TLS_DH_FILE_PATH", "/etc/ssl/dhparam.pem"),
          port: 8888,
          otp_app: :teiserver,
          ciphers: [
            ~c"ECDHE-ECDSA-AES256-GCM-SHA384",
            ~c"ECDHE-RSA-AES256-GCM-SHA384",
            ~c"ECDHE-ECDSA-AES256-SHA384",
            ~c"ECDHE-RSA-AES256-SHA384",
            ~c"ECDHE-ECDSA-DES-CBC3-SHA",
            ~c"ECDH-ECDSA-AES256-GCM-SHA384",
            ~c"ECDH-RSA-AES256-GCM-SHA384",
            ~c"ECDH-ECDSA-AES256-SHA384",
            ~c"ECDH-RSA-AES256-SHA384",
            ~c"DHE-DSS-AES256-GCM-SHA384",
            ~c"DHE-DSS-AES256-SHA256",
            ~c"AES256-GCM-SHA384",
            ~c"AES256-SHA256",
            ~c"ECDHE-ECDSA-AES128-GCM-SHA256",
            ~c"ECDHE-RSA-AES128-GCM-SHA256",
            ~c"ECDHE-ECDSA-AES128-SHA256",
            ~c"ECDHE-RSA-AES128-SHA256",
            ~c"ECDH-ECDSA-AES128-GCM-SHA256",
            ~c"ECDH-RSA-AES128-GCM-SHA256",
            ~c"ECDH-ECDSA-AES128-SHA256",
            ~c"ECDH-RSA-AES128-SHA256",
            ~c"DHE-DSS-AES128-GCM-SHA256",
            ~c"DHE-DSS-AES128-SHA256",
            ~c"AES128-GCM-SHA256",
            ~c"AES128-SHA256",
            ~c"ECDHE-ECDSA-AES256-SHA",
            ~c"ECDHE-RSA-AES256-SHA",
            ~c"DHE-DSS-AES256-SHA",
            ~c"ECDH-ECDSA-AES256-SHA",
            ~c"ECDH-RSA-AES256-SHA",
            ~c"AES256-SHA",
            ~c"ECDHE-ECDSA-AES128-SHA",
            ~c"ECDHE-RSA-AES128-SHA",
            ~c"DHE-DSS-AES128-SHA",
            ~c"ECDH-ECDSA-AES128-SHA",
            ~c"ECDH-RSA-AES128-SHA",
            ~c"AES128-SHA"
          ],
          secure_renegotiate: true,
          reuse_sessions: true,
          honor_cipher_order: true
        ],
    force_ssl: [hsts: true],
    root: ".",
    cache_static_manifest: "priv/static/cache_manifest.json",
    server: true
else
  config :teiserver, Teiserver,
    ports: [
      tcp:
        Teiserver.ConfigHelpers.get_env("TEI_SPRING_TCP_PORT", tei_defaults[:ports][:tcp], :int)
    ]
end

config :teiserver, Teiserver.Account.Guardian,
  issuer: Teiserver.ConfigHelpers.get_env("TEI_GUARDIAN_ISSUER", "teiserver"),
  # the default is only there so we can run it easily
  secret_key:
    Teiserver.ConfigHelpers.get_env(
      "TEI_GUARDIAN_SECRET_KEY",
      Application.get_env(:teiserver, Teiserver.Account.Guardian)[:secret_key]
    ),
  ttl: {30, :days}

config :teiserver, Teiserver.OAuth,
  issuer:
    Teiserver.ConfigHelpers.get_env("TEI_OAUTH_ISSUER", nil) ||
      Application.get_env(:teiserver, Teiserver.OAuth)[:issuer] || "https://#{domain_name}"

if Teiserver.ConfigHelpers.get_env("TEI_ENABLE_EMAIL_INTEGRATION", false, :bool) do
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

log_root_path = Teiserver.ConfigHelpers.get_env("TEI_LOG_ROOT_PATH", "/tmp/teiserver")

config :logger, :error_log, path: "#{log_root_path}/error.log"

config :logger, :notice_log, path: "#{log_root_path}/notice.log"

config :logger, :info_log, path: "#{log_root_path}/info.log"

enable_discord_bridge =
  Teiserver.ConfigHelpers.get_env("TEI_ENABLE_DISCORD_BRIDGE", false, :bool)

config :teiserver, Teiserver,
  discord: "https://discord.gg/beyond-all-reason",
  enable_discord_bridge: enable_discord_bridge

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

config :teiserver, TeiserverWeb.Monitoring,
  port: Teiserver.ConfigHelpers.get_env("TEI_METRICS_SERVER_PORT", 4001, :int)
