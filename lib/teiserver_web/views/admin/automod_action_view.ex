defmodule TeiserverWeb.Admin.AutomodActionView do
  use TeiserverWeb, :view

  @spec view_colour() :: atom
  def view_colour, do: Teiserver.Account.AutomodActionLib.colours()

  @spec icon() :: String.t()
  def icon, do: Teiserver.Account.AutomodActionLib.icon()
end
