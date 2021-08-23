defmodule TeiserverWeb.Game.QueueView do
  use TeiserverWeb, :view

  @spec colours() :: {String.t(), String.t(), String.t()}
  def colours, do: Teiserver.Game.QueueLib.colours()

  @spec icon() :: String.t()
  def icon, do: Teiserver.Game.QueueLib.icon()
end
