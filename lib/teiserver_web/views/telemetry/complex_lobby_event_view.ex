defmodule BarserverWeb.Telemetry.ComplexLobbyEventView do
  use BarserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: Barserver.Telemetry.ComplexLobbyEventLib.colour()

  @spec icon() :: String.t()
  def icon(), do: Barserver.Telemetry.ComplexLobbyEventLib.icon()
end
