defmodule TeiserverWeb.Engine.GeneralView do
  use TeiserverWeb, :view

  def colours(), do: StylingHelper.colours(:default)
  def icon(), do: StylingHelper.icon(:default)

  def colours("units"), do: Teiserver.Engine.UnitLib.colours()
end
