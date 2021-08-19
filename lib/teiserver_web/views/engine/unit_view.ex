defmodule TeiserverWeb.Engine.UnitView do
  use TeiserverWeb, :view

  @spec colours() :: {String.t(), String.t(), String.t()}
  def colours, do: Teiserver.Engine.UnitLib.colours()

  @spec icon() :: String.t()
  def icon, do: Teiserver.Engine.UnitLib.icon()
end
