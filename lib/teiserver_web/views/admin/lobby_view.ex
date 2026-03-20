defmodule TeiserverWeb.Admin.LobbyView do
  alias Teiserver.Lobby

  use TeiserverWeb, :view

  def view_colour, do: Lobby.colours()
  def icon, do: Lobby.icon()
end
