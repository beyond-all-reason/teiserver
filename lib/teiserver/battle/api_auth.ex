defmodule Teiserver.Battle.ApiAuth do
  @moduledoc false
  import Teiserver.Account.AuthLib, only: [allow?: 2]

  @spec authorize(atom(), Plug.Conn.t(), map()) :: bool()
  def authorize(_action, conn, _params), do: allow?(conn, "teiserver.api.battle")
end
