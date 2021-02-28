:ranch.start_listener(
  make_ref(),
  :ranch_ssl,
  [
    {:port, 8200},
    {:certfile, "/priv/certs/localhost.crt"},
    {:cacertfile, "/priv/certs/localhost.crt"},
    {:keyfile, "/priv/certs/localhost.key"}
  ],
  Teiserver.TcpServer,
  []
)
