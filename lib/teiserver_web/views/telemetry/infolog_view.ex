defmodule BarserverWeb.Telemetry.InfologView do
  use BarserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: Barserver.Telemetry.InfologLib.colours()

  @spec icon() :: String.t()
  def icon(), do: Barserver.Telemetry.InfologLib.icon()
end
