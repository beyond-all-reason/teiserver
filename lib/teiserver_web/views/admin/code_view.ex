defmodule BarserverWeb.Admin.CodeView do
  use BarserverWeb, :view

  @spec view_colour() :: {String.t(), String.t(), String.t()}
  def view_colour(), do: Barserver.Account.CodeLib.colours()

  @spec icon() :: String.t()
  def icon(), do: Barserver.Account.CodeLib.icon()
end
