defmodule TeiserverWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :central

  @session_options [
    store: :cookie,
    key: "_central_key",
    signing_salt: "zv0zamJX",
    same_site: "Lax",
    max_age: 1_814_400
  ]

  socket("/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]])

  socket("/socket", TeiserverWeb.UserSocket,
    websocket: true,
    longpoll: false
  )

  socket("/tachyon", Teiserver.Tachyon.TachyonSocket,
    websocket: [
      connect_info: [:peer_data, :x_headers, :user_agent],
      error_handler: {Teiserver.Tachyon.TachyonSocket, :handle_error, []}
    ],
    longpoll: false
  )

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug(Plug.Static,
    at: "/",
    from: :central,
    gzip: true,
    only: CentralWeb.static_paths()
  )

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket("/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket)
    plug(Phoenix.LiveReloader)
    plug(Phoenix.CodeReloader)
    plug(Phoenix.Ecto.CheckRepoStatus, otp_app: :central)
  end

  plug(Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"
  )

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, {:multipart, length: 500_000_000}, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  plug(Plug.Session, @session_options)

  plug(TeiserverWeb.Router)
end
