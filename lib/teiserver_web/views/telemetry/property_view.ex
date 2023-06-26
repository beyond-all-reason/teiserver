defmodule TeiserverWeb.Telemetry.PropertyView do
  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: Teiserver.Telemetry.PropertyTypeLib.colours()

  @spec icon() :: String.t()
  def icon(), do: Teiserver.Telemetry.PropertyTypeLib.icon()
end
