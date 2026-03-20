defmodule TeiserverWeb.Admin.LobbyPolicyView do
  alias Teiserver.Game.LobbyPolicyLib

  use TeiserverWeb, :view

  def view_colour, do: LobbyPolicyLib.colours()
  def icon, do: LobbyPolicyLib.icon()
end
