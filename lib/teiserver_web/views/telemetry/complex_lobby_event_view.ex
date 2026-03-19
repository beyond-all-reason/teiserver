defmodule TeiserverWeb.Telemetry.ComplexLobbyEventView do
  use TeiserverWeb, :view

  alias Teiserver.Telemetry.ComplexLobbyEventLib

  @spec view_colour :: atom
  def view_colour(), do: ComplexLobbyEventLib.colour()

  @spec icon() :: String.t()
  def icon(), do: ComplexLobbyEventLib.icon()
end
