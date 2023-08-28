defmodule TeiserverWeb.Telemetry.SimpleClientEventView do
  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: Teiserver.Telemetry.SimpleClientEventLib.colour()

  @spec icon() :: String.t()
  def icon(), do: Teiserver.Telemetry.SimpleClientEventLib.icon()
end
