defmodule TeiserverWeb.Telemetry.SimpleLobbyEventView do
  use TeiserverWeb, :view

  alias Teiserver.Telemetry.SimpleLobbyEventLib

  @spec view_colour :: atom
  def view_colour(), do: SimpleLobbyEventLib.colour()

  @spec icon() :: String.t()
  def icon(), do: SimpleLobbyEventLib.icon()
end
