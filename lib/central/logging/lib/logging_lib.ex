defmodule Central.Logging.LoggingLib do
  @moduledoc false
  import Plug.Conn, only: [assign: 3]

  @spec colours() :: atom
  def colours(), do: :default

  @spec icon() :: String.t()
  def icon(), do: "fa-regular fa-bars"

  @spec do_not_log(Plug.Conn.t()) :: Plug.Conn.t()
  def do_not_log(conn) do
    assign(conn, :do_not_log, true)
  end

  @spec authorize(any, Plug.Conn.t(), atom) :: boolean
  def authorize(_, conn, _), do: Central.Account.AuthLib.allow?(conn, "logging")
end
