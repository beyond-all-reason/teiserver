defmodule TeiserverWeb.Clan.ClanView do
  use TeiserverWeb, :view

  def colours, do: Teiserver.Clan.ClanLib.colours()
  def icon, do: Teiserver.Clan.ClanLib.icon()
end
