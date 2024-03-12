defmodule Barserver.Battle.ApiAuth do
  import Barserver.Account.AuthLib, only: [allow?: 2]

  @spec authorize(Atom.t(), Plug.Conn.t(), Map.t()) :: Boolean.t()
  def authorize(_, conn, _), do: allow?(conn, "teiserver.api.battle")
end
