defmodule TeiserverWeb.Admin.BanHashView do
  use TeiserverWeb, :view

  @spec view_colour() :: atom
  def view_colour, do: Teiserver.Account.BanHashLib.colours()

  @spec icon() :: String.t()
  def icon, do: Teiserver.Account.BanHashLib.icon()
end
