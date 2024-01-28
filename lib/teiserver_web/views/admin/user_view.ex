defmodule BarserverWeb.Admin.UserView do
  use BarserverWeb, :view

  @spec view_colour :: atom()
  def view_colour(), do: Barserver.Account.UserLib.colours()

  @spec icon :: String.t()
  def icon(), do: Barserver.Account.UserLib.icon()
end
