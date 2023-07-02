defmodule TeiserverWeb.Admin.LobbyView do
  use TeiserverWeb, :view

  def view_colour, do: Teiserver.Lobby.colours()
  def icon, do: Teiserver.Lobby.icon()
end
