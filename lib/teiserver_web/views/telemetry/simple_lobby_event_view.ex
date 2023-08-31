defmodule TeiserverWeb.Telemetry.SimpleLobbyEventView do
  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: Teiserver.Telemetry.SimpleLobbyEventLib.colour()

  @spec icon() :: String.t()
  def icon(), do: Teiserver.Telemetry.SimpleLobbyEventLib.icon()
end
