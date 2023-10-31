defmodule Teiserver.Admin.AdminLib do
  @moduledoc false
  use TeiserverWeb, :library

  @spec colours :: atom
  def colours(), do: :info2

  @spec icon() :: String.t()
  def icon(), do: "fa-user-circle"

  @spec authorize(any, Plug.Conn.t(), atom) :: boolean
  def authorize(_, conn, _), do: Teiserver.Account.AuthLib.allow?(conn, "Admin")
end
