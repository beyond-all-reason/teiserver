defmodule BarserverWeb.Telemetry.GeneralView do
  use BarserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: :primary

  @spec icon() :: String.t()
  def icon(), do: StylingHelper.icon(:primary)

  @spec view_colour(String.t()) :: atom
  def view_colour("infologs"), do: Barserver.Telemetry.InfologLib.colours()
  def view_colour("properties"), do: Barserver.Telemetry.PropertyTypeLib.colours()
  def view_colour("client_events"), do: Barserver.Telemetry.ComplexClientEventLib.colour()
  def view_colour("complex_server_events"), do: Barserver.Telemetry.ComplexServerEventLib.colour()
  def view_colour("match_events"), do: Barserver.Telemetry.SimpleMatchEventLib.colour()
  def view_colour("complex_match_events"), do: Barserver.Telemetry.ComplexMatchEventLib.colour()
end
