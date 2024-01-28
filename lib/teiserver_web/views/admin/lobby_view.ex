defmodule BarserverWeb.Admin.LobbyView do
  use BarserverWeb, :view

  def view_colour, do: Barserver.Lobby.colours()
  def icon, do: Barserver.Lobby.icon()
end
