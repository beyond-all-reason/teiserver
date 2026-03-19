defmodule TeiserverWeb.Admin.LobbyPolicyView do
  use TeiserverWeb, :view

  alias Teiserver.Game.LobbyPolicyLib

  def view_colour, do: LobbyPolicyLib.colours()
  def icon, do: LobbyPolicyLib.icon()
end
