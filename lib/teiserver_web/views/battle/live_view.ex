defmodule TeiserverWeb.Battle.LiveView do
  use TeiserverWeb, :view

  def view_colour(), do: Teiserver.Battle.LobbyLib.colours()
  def icon(), do: Teiserver.Battle.LobbyLib.icon()
end
