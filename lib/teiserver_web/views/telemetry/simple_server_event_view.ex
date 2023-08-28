defmodule TeiserverWeb.Telemetry.SimpleServerEventView do
  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: Teiserver.Telemetry.SimpleServerEventLib.colour()

  @spec icon() :: String.t()
  def icon(), do: Teiserver.Telemetry.SimpleServerEventLib.icon()
end
