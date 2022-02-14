defmodule Central.Admin.AdminLib do
  @moduledoc false
  use CentralWeb, :library

  @spec colours :: atom
  def colours(), do: :info2

  @spec icon() :: String.t()
  def icon(), do: "fas fa-user-circle"

  @spec authorize(any, Plug.Conn.t(), atom) :: boolean
  def authorize(_, conn, _), do: Central.Account.AuthLib.allow?(conn, "admin")
end
