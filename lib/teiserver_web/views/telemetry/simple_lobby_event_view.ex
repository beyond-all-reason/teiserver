defmodule TeiserverWeb.Telemetry.SimpleLobbyEventView do
  alias Teiserver.Telemetry.SimpleLobbyEventLib

  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour, do: SimpleLobbyEventLib.colour()

  @spec icon() :: String.t()
  def icon, do: SimpleLobbyEventLib.icon()
end
