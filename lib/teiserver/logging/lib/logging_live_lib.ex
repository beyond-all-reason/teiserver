defmodule Teiserver.Logging.LiveLib do
  @moduledoc false
  alias Teiserver.Account.AuthLib

  @spec authorize(any, Plug.Conn.t(), atom) :: boolean
  def authorize(_, conn, _), do: AuthLib.allow?(conn, "logging.live")
end
