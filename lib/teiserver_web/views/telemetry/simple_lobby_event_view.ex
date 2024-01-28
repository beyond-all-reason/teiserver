defmodule BarserverWeb.Telemetry.SimpleLobbyEventView do
  use BarserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: Barserver.Telemetry.SimpleLobbyEventLib.colour()

  @spec icon() :: String.t()
  def icon(), do: Barserver.Telemetry.SimpleLobbyEventLib.icon()
end
