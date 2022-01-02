# In this file, we load production configuration and secrets
# from environment variables. You can also hardcode secrets,
# although such is generally not recommended and you have to
# remember to add this file to your .gitignore.
use Mix.Config

secret_key_base = "mix phx.gen.secret"

config :central, Central.Setup,
  key: "---- random string of alpha numeric characters ----"

# This can be part of your standard prod.exs but I wanted it to
# default to not going into a github repo
config :central, CentralWeb.Endpoint,
  url: [host: "yourdomain.com"],
  https: [
    keyfile: "/etc/letsencrypt/live/yourdomain.com/privkey.pem",
    certfile: "/etc/letsencrypt/live/yourdomain.com/cert.pem",
    cacertfile: "/etc/letsencrypt/live/yourdomain.com/fullchain.pem"
  ],
  check_origin: ["//yourdomain.com", "//*.yourdomain.com"]

config :central, Teiserver,
  game_name: "My game name",
  game_name_short: "GN",
  main_website: "https://site.com",
  privacy_email: "privacy@site.com",
  discord: "My discord link"# Set to nil to not have link,
  certs: [
    keyfile: "/etc/letsencrypt/live/yourdomain.com/privkey.pem",
    certfile: "/etc/letsencrypt/live/yourdomain.com/cert.pem",
    cacertfile: "/etc/letsencrypt/live/yourdomain.com/fullchain.pem"
  ]

config :central, Central.Repo,
  username: "teiserver_prod",
  password: "mix phx.gen.secret",
  database: "teiserver_prod",
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
  timeout: 30_000

config :central, CentralWeb.Endpoint,
  http: [:inet6, port: String.to_integer(System.get_env("PORT") || "4000")],
  secret_key_base: secret_key_base

config :central, Central.Account.Guardian,
  issuer: "central",
  secret_key: "mix phx.gen.secret"

config :central, Central.Mailer,
  noreply_address: "noreply@yourdomain.com",
  contact_address: "info@yourdomain.com",
  adapter: Bamboo.SMTPAdapter,
  server: "mailserver",
  hostname: "yourdomain.com",
  # port: 1025,
  port: 587,
  # or {:system, "SMTP_USERNAME"}
  username: "noreply@yourdomain.com",
  # or {:system, "SMTP_PASSWORD"}
  password: "mix phx.gen.secret",
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
