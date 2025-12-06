defmodule TeiserverWeb.Admin.CodeView do
  use TeiserverWeb, :view

  @spec view_colour() :: atom()
  def view_colour(), do: Teiserver.Account.CodeLib.colours()

  @spec icon() :: String.t()
  def icon(), do: Teiserver.Account.CodeLib.icon()
end
