defmodule TeiserverWeb.Telemetry.MatchEventView do
  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: Teiserver.Telemetry.MatchEventLib.colour()

  @spec icon() :: String.t()
  def icon(), do: Teiserver.Telemetry.MatchEventLib.icon()
end
