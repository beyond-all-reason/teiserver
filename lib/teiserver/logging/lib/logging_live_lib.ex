defmodule Barserver.Logging.LiveLib do
  @moduledoc false
  @spec authorize(any, Plug.Conn.t(), atom) :: boolean
  def authorize(_, conn, _), do: Barserver.Account.AuthLib.allow?(conn, "logging.live")
end
