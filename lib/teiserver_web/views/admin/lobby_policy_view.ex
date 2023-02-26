defmodule TeiserverWeb.Admin.LobbyPolicyView do
  use TeiserverWeb, :view

  def view_colour, do: Teiserver.Game.LobbyPolicyLib.colours()
  def icon, do: Teiserver.Game.LobbyPolicyLib.icon()
end
