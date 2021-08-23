defmodule TeiserverWeb.Game.GeneralView do
  use TeiserverWeb, :view

  def colours(), do: StylingHelper.colours(:default)
  def icon(), do: StylingHelper.icon(:default)

  def colours("queues"), do: Teiserver.Game.QueueLib.colours()
end
