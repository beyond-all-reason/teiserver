defmodule BarserverWeb.General.GeneralView do
  use BarserverWeb, :view

  def view_colour(), do: :primary
  def icon(), do: StylingHelper.icon(:primary)
end
