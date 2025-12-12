defmodule Teiserver.Battle.ApiAuth do
  import Teiserver.Account.AuthLib, only: [allow?: 2]

  @spec authorize(atom(), Plug.Conn.t(), map()) :: bool()
  def authorize(_, conn, _), do: allow?(conn, "teiserver.api.battle")
end
