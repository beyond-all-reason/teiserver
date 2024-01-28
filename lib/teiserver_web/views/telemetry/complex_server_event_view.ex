defmodule BarserverWeb.Telemetry.ComplexServerEventView do
  use BarserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: Barserver.Telemetry.ComplexServerEventLib.colour()

  @spec icon() :: String.t()
  def icon(), do: Barserver.Telemetry.ComplexServerEventLib.icon()
end
