defmodule BarserverWeb.Admin.AccoladeView do
  use BarserverWeb, :view

  @spec view_colour() :: atom
  def view_colour, do: Barserver.Account.AccoladeLib.colours()

  @spec icon() :: String.t()
  def icon, do: Barserver.Account.AccoladeLib.icon()
end
