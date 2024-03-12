defmodule BarserverWeb.Game.QueueView do
  use BarserverWeb, :view

  @spec view_colour() :: atom
  def view_colour, do: Barserver.Game.QueueLib.colours()

  @spec icon() :: String.t()
  def icon, do: Barserver.Game.QueueLib.icon()
end
