defmodule BarserverWeb.Game.GeneralView do
  use BarserverWeb, :view

  def view_colour(), do: :default
  def icon(), do: StylingHelper.icon(:default)

  def view_colour("queues"), do: Barserver.Game.QueueLib.colours()
end
