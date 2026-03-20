defmodule TeiserverWeb.Telemetry.ComplexLobbyEventView do
  alias Teiserver.Telemetry.ComplexLobbyEventLib

  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: ComplexLobbyEventLib.colour()

  @spec icon() :: String.t()
  def icon(), do: ComplexLobbyEventLib.icon()
end
