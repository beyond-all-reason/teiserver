defmodule TeiserverWeb.Telemetry.GeneralView do
  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: :primary

  @spec icon() :: String.t()
  def icon(), do: StylingHelper.icon(:primary)

  @spec view_colour(String.t()) :: atom
  def view_colour("infologs"), do: Teiserver.Telemetry.InfologLib.colours()
  def view_colour("properties"), do: Teiserver.Telemetry.PropertyTypeLib.colours()
  def view_colour("client_events"), do: Teiserver.Telemetry.ComplexClientEventLib.colour()
  def view_colour("complex_server_events"), do: Teiserver.Telemetry.ComplexServerEventLib.colour()
  def view_colour("match_events"), do: Teiserver.Telemetry.SimpleMatchEventLib.colour()
  def view_colour("complex_match_events"), do: Teiserver.Telemetry.ComplexMatchEventLib.colour()
end
