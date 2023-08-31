defmodule TeiserverWeb.Telemetry.SimpleMatchEventView do
  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: Teiserver.Telemetry.SimpleMatchEventLib.colour()

  @spec icon() :: String.t()
  def icon(), do: Teiserver.Telemetry.SimpleMatchEventLib.icon()
end
