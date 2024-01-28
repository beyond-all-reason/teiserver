defmodule BarserverWeb.Telemetry.ComplexMatchEventView do
  use BarserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: Barserver.Telemetry.ComplexMatchEventLib.colour()

  @spec icon() :: String.t()
  def icon(), do: Barserver.Telemetry.ComplexMatchEventLib.icon()
end
