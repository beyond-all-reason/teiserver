import Config

domain = System.get_env("DOMAIN_NAME")

dbHostname = System.get_env("POSTGRES_HOSTNAME")
dbPort = System.get_env("POSTGRES_PORT") || "5432" |> String.to_integer
dbUser = System.get_env("POSTGRES_USER")
dbPassword = System.get_env("POSTGRES_PASSWORD")
dbDB = System.get_env("POSTGRES_DB")
dbConnectionPoolSize = System.get_env("DB_CONN_POOL_SIZE") || "10" |> String.to_integer
dbConnectionTimeout = System.get_env("DB_CONN_TIMEOUT") || "64000" |> String.to_integer

centralWebKey = System.get_env("WEB_KEY")
centralWebKeyBase = System.get_env("WEB_KEY_BASE")
centralAccountGuardianKey = System.get_env("ACCOUNT_GUARD_KEY")

discordToken = System.get_env("DISCORD_TOKEN")

gameName = System.get_env("GAME_NAME")
gameNameShort = System.get_env("GAME_NAME_SHORT")
website = System.get_env("WEBSITE")
privacyEmail = System.get_env("PRIVACY_EMAIL")

config :central, CentralWeb.Setup,
  key: centralWebKey
#  key: :crypto.strong_rand_bytes(64) |> Base.encode16 |> binary_part(0, 64)

config :central, CentralWeb.Endpoint,
  check_origin: [Enum.join(["//", domain], ""), Enum.join(["//*.", domain], "")],
  url: [host: domain],
  secret_key_base: centralWebKeyBase,
  server: true,
  root: "/app",
  http: [
    ip: {0, 0, 0, 0},
    port: 8080
  ],
  https: false

config :central, Teiserver,
  game_name: gameName,
  game_name_short: gameNameShort,
  main_website: website,
  privacy_email: privacyEmail,
  certs: [
    keyfile: "/run/secrets/privkey.pem",
    certfile: "/run/secrets/cert.pem",
    cacertfile: "/run/secrets/fullchain.pem"
  ]

config :central, Central.Repo,
  username: dbUser,
  password: dbPassword,
  database: dbDB,
#  migration_lock: false,
  hostname: dbHostname,
  port: dbPort,
  pool_size: dbConnectionPoolSize,
  timeout: dbConnectionTimeout

config :central, Central.Account.Guardian,
  issuer: "central",
  secret_key: centralAccountGuardianKey
#  secret_key: :crypto.strong_rand_bytes(64) |> Base.encode16 |> binary_part(0, 64)

config :nostrum,
  token: discordToken

#config :central, Central.Mailer,
#  noreply_address: "noreply@yourdomain.com",
#  contact_address: "info@yourdomain.com",
#  adapter: Bamboo.SMTPAdapter,
#  server: "mailserver",
#  hostname: "yourdomain.com",
#  # port: 1025,
#  port: 587,
#  # or {:system, "SMTP_USERNAME"}
#  username: "noreply@yourdomain.com",
#  # or {:system, "SMTP_PASSWORD"}
#  password: "mix phx.gen.secret",
#  # tls: :if_available, # can be `:always` or `:never`
#  # can be `:always` or `:never`
#  tls: :always,
#  # or {":system", ALLOWED_TLS_VERSIONS"} w/ comma seprated values (e.g. "tlsv1.1,tlsv1.2")
#  allowed_tls_versions: [:tlsv1, :"tlsv1.1", :"tlsv1.2"],
#  # can be `true`
#  ssl: false,
#  retries: 1,
#  # can be `true`
#  no_mx_lookups: false,
#  # auth: :if_available # can be `always`. If your smtp relay requires authentication set it to `always`.
#  auth: :always
