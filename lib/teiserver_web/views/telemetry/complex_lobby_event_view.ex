defmodule TeiserverWeb.Telemetry.ComplexLobbyEventView do
  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: Teiserver.Telemetry.ComplexLobbyEventLib.colour()

  @spec icon() :: String.t()
  def icon(), do: Teiserver.Telemetry.ComplexLobbyEventLib.icon()
end
