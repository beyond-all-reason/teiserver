defmodule BarserverWeb.Telemetry.SimpleServerEventView do
  use BarserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: Barserver.Telemetry.SimpleServerEventLib.colour()

  @spec icon() :: String.t()
  def icon(), do: Barserver.Telemetry.SimpleServerEventLib.icon()
end
