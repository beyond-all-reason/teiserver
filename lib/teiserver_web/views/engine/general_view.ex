defmodule TeiserverWeb.Engine.GeneralView do
  use TeiserverWeb, :view

  def view_colour(), do: :default
  def icon(), do: StylingHelper.icon(:default)

  def view_colour("units"), do: Teiserver.Engine.UnitLib.colours()
end
