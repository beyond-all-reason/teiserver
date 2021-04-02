defmodule TeiserverWeb.Clans.ClanView do
  use TeiserverWeb, :view

  def colours, do: Teiserver.Clans.ClanLib.colours()
  def icon, do: Teiserver.Clans.ClanLib.icon()
end
