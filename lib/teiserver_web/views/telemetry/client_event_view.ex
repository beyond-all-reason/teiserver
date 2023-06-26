defmodule TeiserverWeb.Telemetry.ClientEventView do
  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: Teiserver.Telemetry.ClientEventLib.colour()

  @spec icon() :: String.t()
  def icon(), do: Teiserver.Telemetry.ClientEventLib.icon()
end
