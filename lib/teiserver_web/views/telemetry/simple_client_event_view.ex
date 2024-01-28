defmodule BarserverWeb.Telemetry.SimpleClientEventView do
  use BarserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: Barserver.Telemetry.SimpleClientEventLib.colour()

  @spec icon() :: String.t()
  def icon(), do: Barserver.Telemetry.SimpleClientEventLib.icon()
end
