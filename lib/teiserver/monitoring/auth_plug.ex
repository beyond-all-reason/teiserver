defmodule Teiserver.Monitoring.AuthPlug do
  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    # Little bit of a weird logic there. This is so that one can run
    # the dev version of teiserver without having to modify anything
    # but can also override the password with env vars
    conf = Application.get_env(:teiserver, TeiserverWeb.Monitoring)

    expected_pass =
      case conf[:prometheus_password] do
        :unset -> conf[:config_prometheus_password]
        pass -> pass
      end

    Plug.BasicAuth.basic_auth(conn, username: conf[:prometheus_username], password: expected_pass)
  end
end
