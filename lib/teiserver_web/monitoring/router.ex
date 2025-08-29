defmodule TeiserverWeb.Monitoring.Router do
  use Plug.Router

  plug :match
  plug :dispatch

  forward "/metrics",
    to: PromEx.MetricsServer.Plug,
    init_opts: %{prom_ex_module: Teiserver.PromEx, path: "/metrics"}

  match _ do
    send_resp(conn, 404, "Not Found")
  end

  def port() do
    Application.get_env(:teiserver, TeiserverWeb.Monitoring)[:port]
  end
end
