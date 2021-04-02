defmodule TeiserverWeb.Clans.GeneralView do
  use TeiserverWeb, :view

  def colours(), do: StylingHelper.colours(:success)
  def icon(), do: StylingHelper.icon(:success)

  def colours("relationships"), do: StylingHelper.colours(:info)
  def colours("clans"), do: StylingHelper.colours(:info)
end
