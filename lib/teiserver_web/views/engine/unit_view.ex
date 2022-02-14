defmodule TeiserverWeb.Engine.UnitView do
  use TeiserverWeb, :view

  @spec view_colour() :: atom
  def view_colour, do: Teiserver.Engine.UnitLib.colours()

  @spec icon() :: String.t()
  def icon, do: Teiserver.Engine.UnitLib.icon()
end
