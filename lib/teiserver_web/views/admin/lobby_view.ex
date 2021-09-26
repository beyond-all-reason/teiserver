defmodule TeiserverWeb.Admin.LobbyView do
  use TeiserverWeb, :view

  def colours, do: Teiserver.Battle.LobbyLib.colours()
  def icon, do: Teiserver.Battle.LobbyLib.icon()
end
