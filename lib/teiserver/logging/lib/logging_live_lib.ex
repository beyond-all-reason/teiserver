defmodule Teiserver.Logging.LiveLib do
  @moduledoc false
  alias Teiserver.Account.Auth

  @spec authorize(any, Plug.Conn.t(), atom) :: boolean
  def authorize(_data, conn, _action), do: Auth.allow?(conn, "logging.live")
end
