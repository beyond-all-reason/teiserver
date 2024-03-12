defmodule BarserverWeb.Admin.LobbyPolicyView do
  use BarserverWeb, :view

  def view_colour, do: Barserver.Game.LobbyPolicyLib.colours()
  def icon, do: Barserver.Game.LobbyPolicyLib.icon()
end
