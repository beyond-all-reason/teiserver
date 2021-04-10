defmodule Central.Admin.AdminLib do
  use CentralWeb, :library

  @spec colours :: {String.t(), String.t(), String.t()}
  def colours(), do: Central.Helpers.StylingHelper.colours(:info2)
  @spec icon() :: String.t()
  def icon(), do: "fas fa-user-circle"

  @spec authorize(any, Plug.Conn.t(), atom) :: boolean
  def authorize(_, conn, _), do: Central.Account.AuthLib.allow?(conn, "admin")
end
