defmodule BarserverWeb.Telemetry.SimpleMatchEventView do
  use BarserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: Barserver.Telemetry.SimpleMatchEventLib.colour()

  @spec icon() :: String.t()
  def icon(), do: Barserver.Telemetry.SimpleMatchEventLib.icon()
end
