defmodule TeiserverWeb.Telemetry.ComplexMatchEventView do
  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: Teiserver.Telemetry.ComplexMatchEventLib.colour()

  @spec icon() :: String.t()
  def icon(), do: Teiserver.Telemetry.ComplexMatchEventLib.icon()
end
