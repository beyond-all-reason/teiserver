defmodule TeiserverWeb.Clans.GeneralView do
  use TeiserverWeb, :view

  def view_colour(), do: :success
  def icon(), do: StylingHelper.icon(:success)

  def view_colour("relationships"), do: StylingHelper.colours(:info)
  def view_colour("clans"), do: StylingHelper.colours(:info)
end
