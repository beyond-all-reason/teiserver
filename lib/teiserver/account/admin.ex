defmodule Teiserver.Account.Admin do
  # Used to provide permissions for tools controller until a better solution is created
  @behaviour Bodyguard.Policy
  import Central.Account.AuthLib, only: [allow?: 2]

  @spec authorize(any, Plug.Conn.t(), atom) :: boolean
  def authorize(:convert_form, conn, _), do: allow?(conn, "admin.dev")
  def authorize(:convert_post, conn, _), do: allow?(conn, "admin.dev")
  def authorize(_, conn, _), do: allow?(conn, "Admin")
end
