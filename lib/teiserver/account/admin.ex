defmodule Teiserver.Account.Admin do
  @moduledoc false
  import Teiserver.Account.AuthLib, only: [allow?: 2]
  # Used to provide permissions for tools controller until a better solution is created
  @behaviour Bodyguard.Policy

  @spec authorize(any, Plug.Conn.t(), atom) :: boolean
  def authorize(:convert_form, conn, _), do: allow?(conn, "admin.dev")
  def authorize(:convert_post, conn, _), do: allow?(conn, "admin.dev")
  def authorize(_, conn, _), do: allow?(conn, "Admin")
end
