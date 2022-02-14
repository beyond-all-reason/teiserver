defmodule TeiserverWeb.Admin.ClanView do
  use TeiserverWeb, :view

  def view_colour, do: Teiserver.Clans.ClanLib.colours()
  def icon, do: Teiserver.Clans.ClanLib.icon()
end
