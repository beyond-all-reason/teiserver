defmodule TeiserverWeb.Telemetry.ComplexServerEventView do
  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: Teiserver.Telemetry.ComplexServerEventLib.colour()

  @spec icon() :: String.t()
  def icon(), do: Teiserver.Telemetry.ComplexServerEventLib.icon()
end
