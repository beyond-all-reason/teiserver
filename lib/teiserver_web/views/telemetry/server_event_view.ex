defmodule TeiserverWeb.Telemetry.ServerEventView do
  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: Teiserver.Telemetry.ServerEventLib.colour()

  @spec icon() :: String.t()
  def icon(), do: Teiserver.Telemetry.ServerEventLib.icon()
end
