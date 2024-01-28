defmodule Barserver.Admin.AdminLib do
  @moduledoc false
  use BarserverWeb, :library

  @spec colours :: atom
  def colours(), do: :info2

  @spec icon() :: String.t()
  def icon(), do: "fa-user-circle"

  @spec authorize(any, Plug.Conn.t(), atom) :: boolean
  def authorize(_, conn, _), do: Barserver.Account.AuthLib.allow?(conn, "Admin")
end
