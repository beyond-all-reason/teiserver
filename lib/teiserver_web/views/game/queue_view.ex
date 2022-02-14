defmodule TeiserverWeb.Game.QueueView do
  use TeiserverWeb, :view

  @spec view_colour() :: atom
  def view_colour, do: Teiserver.Game.QueueLib.colours()

  @spec icon() :: String.t()
  def icon, do: Teiserver.Game.QueueLib.icon()
end
