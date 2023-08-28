defmodule TeiserverWeb.Telemetry.InfologView do
  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: Teiserver.Telemetry.InfologLib.colours()

  @spec icon() :: String.t()
  def icon(), do: Teiserver.Telemetry.InfologLib.icon()
end
