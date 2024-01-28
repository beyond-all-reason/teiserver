defmodule BarserverWeb.Telemetry.ComplexClientEventView do
  use BarserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: Barserver.Telemetry.ComplexClientEventLib.colour()

  @spec icon() :: String.t()
  def icon(), do: Barserver.Telemetry.ComplexClientEventLib.icon()
end
