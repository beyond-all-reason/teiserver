defmodule TeiserverWeb.Game.GeneralView do
  use TeiserverWeb, :view

  def view_colour(), do: :default
  def icon(), do: StylingHelper.icon(:default)

  def view_colour("queues"), do: Teiserver.Game.QueueLib.colours()
end
