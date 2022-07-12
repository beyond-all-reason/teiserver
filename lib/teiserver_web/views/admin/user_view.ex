defmodule TeiserverWeb.Admin.UserView do
  use TeiserverWeb, :view

  @spec view_colour :: atom()
  def view_colour(), do: Teiserver.Account.UserLib.colours()

  @spec icon :: String.t()
  def icon(), do: Teiserver.Account.UserLib.icon()
end
