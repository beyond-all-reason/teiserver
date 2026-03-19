defmodule TeiserverWeb.Admin.LobbyView do
  use TeiserverWeb, :view

  alias Teiserver.Lobby

  def view_colour, do: Lobby.colours()
  def icon, do: Lobby.icon()
end
