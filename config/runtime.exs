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
  blog_allow_upload: System.get_env("TEI_BLOG_ALLOW_UPLOAD") == "TRUE",
  blog_upload_path: System.get_env("TEI_BLOG_UPLOAD_PATH"),
  blog_upload_extensions:
    System.get_env("TEI_BLOG_UPLOAD_EXTENSIONS", ".jpg .jpeg .png") |> String.split(" ")

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

spring_listeners =
  Application.get_env(:teiserver, Teiserver.SpringTcpServer)
  |> Keyword.fetch!(:listeners)

tei_defaults = Application.get_env(:teiserver, Teiserver)

spring_listeners =
  Application.get_env(:teiserver, Teiserver.SpringTcpServer)
  |> Keyword.fetch!(:listeners)

spring_listeners =
  if Keyword.get(spring_listeners, :tcp) do
    # If TCP listener is enabled put the port option
    get_and_update_in(spring_listeners, [:tcp, :socket_opts, :port], fn default ->
      {default, Teiserver.ConfigHelpers.get_env("TEI_SPRING_TCP_PORT", default, :int)}
    end)
    |> elem(1)
  else
    spring_listeners
  end

use_tls? =
  Teiserver.ConfigHelpers.get_env("TEI_TLS_PRIVATE_KEY_PATH", nil) != nil

if use_tls? do
  cert_opts = [
    keyfile: System.get_env("TEI_TLS_PRIVATE_KEY_PATH"),
    certfile: System.get_env("TEI_TLS_CERT_PATH"),
    cacertfile: System.get_env("TEI_TLS_CA_CERT_PATH")
  ]

  spring_listeners =
    if Keyword.get(spring_listeners, :tls) do
      # If TLS listener is enabled put the certificate and port options
      get_and_update_in(
        spring_listeners,
        [:tls, :socket_opts],
        fn socket_opts ->
          new_opts = Keyword.merge(socket_opts, cert_opts)

          default_port = Keyword.fetch!(socket_opts, :port)
          port = Teiserver.ConfigHelpers.get_env("TEI_SPRING_TLS_PORT", default_port, :int)

          {socket_opts, Keyword.put(new_opts, :port, port)}
        end
      )
      |> elem(1)
    else
      spring_listeners
    end

  config :teiserver, Teiserver.SpringTcpServer, listeners: spring_listeners

  if Keyword.get(endpoint_defaults, :https) do
    config :teiserver, TeiserverWeb.Endpoint,
      force_ssl: [hsts: true],
      root: ".",
      cache_static_manifest: "priv/static/cache_manifest.json",
      server: true,
      https:
        Keyword.merge(
          cert_opts,
          # dhfile is not supported for tls 1.3
          # https://www.erlang.org/doc/man/ssl.html#type-dh_file
          dhfile: Teiserver.ConfigHelpers.get_env("TEI_TLS_DH_FILE_PATH", "/etc/ssl/dhparam.pem")
        )
  end
else
  config :teiserver, Teiserver.SpringTcpServer,
    listeners: Keyword.put(spring_listeners, :tls, nil)

  config :teiserver, TeiserverWeb.Endpoint, https: nil
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
