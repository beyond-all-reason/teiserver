defmodule BarserverWeb.Telemetry.PropertyView do
  use BarserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: Barserver.Telemetry.PropertyTypeLib.colours()

  @spec icon() :: String.t()
  def icon(), do: Barserver.Telemetry.PropertyTypeLib.icon()
end
