defmodule Teiserver.Logging.LiveLib do
  @moduledoc false
  alias Teiserver.Account.AuthLib

  @spec authorize(any, Plug.Conn.t(), atom) :: boolean
  def authorize(_data, conn, _action), do: AuthLib.allow?(conn, "logging.live")
end
