defmodule TeiserverWeb.Telemetry.ComplexClientEventView do
  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: Teiserver.Telemetry.ComplexClientEventLib.colour()

  @spec icon() :: String.t()
  def icon(), do: Teiserver.Telemetry.ComplexClientEventLib.icon()
end
