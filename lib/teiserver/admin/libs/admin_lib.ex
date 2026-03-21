defmodule Teiserver.Admin.AdminLib do
  @moduledoc false

  alias Teiserver.Account.AuthLib
  use TeiserverWeb, :library

  @spec colours :: atom
  def colours, do: :info2

  @spec icon() :: String.t()
  def icon, do: "fa-user-circle"

  @spec authorize(any, Plug.Conn.t(), atom) :: boolean
  def authorize(_action, conn, _params), do: AuthLib.allow?(conn, "Admin")
end
