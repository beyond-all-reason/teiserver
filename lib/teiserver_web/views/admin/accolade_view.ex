defmodule TeiserverWeb.Admin.AccoladeView do
  use TeiserverWeb, :view

  @spec view_colour() :: atom
  def view_colour, do: Teiserver.Account.AccoladeLib.colours()

  @spec icon() :: String.t()
  def icon, do: Teiserver.Account.AccoladeLib.icon()
end
