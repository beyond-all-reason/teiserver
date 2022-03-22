defmodule Central.Admin do
  @moduledoc false
  @behaviour Bodyguard.Policy

  import Central.Account.AuthLib, only: [allow?: 2]

  # def colours, do: {"#2A4", "#EFE", "success"}
  def icon, do: "fa-duotone fa-user-circle"

  def authorize(_, conn, _), do: allow?(conn, "admin")
  # def authorize(_, _, _), do: false
end
