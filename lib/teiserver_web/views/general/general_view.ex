defmodule TeiserverWeb.General.GeneralView do
  use TeiserverWeb, :view

  def view_colour(), do: :primary
  def icon(), do: StylingHelper.icon(:primary)
end
