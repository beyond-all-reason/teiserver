defmodule TeiserverWeb.Telemetry.GeneralView do
  alias Teiserver.Telemetry.ComplexClientEventLib
  alias Teiserver.Telemetry.ComplexMatchEventLib
  alias Teiserver.Telemetry.ComplexServerEventLib
  alias Teiserver.Telemetry.InfologLib
  alias Teiserver.Telemetry.PropertyTypeLib
  alias Teiserver.Telemetry.SimpleMatchEventLib

  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour, do: :primary

  @spec icon() :: String.t()
  def icon, do: StylingHelper.icon(:primary)

  @spec view_colour(String.t()) :: atom
  def view_colour("infologs"), do: InfologLib.colours()
  def view_colour("properties"), do: PropertyTypeLib.colours()
  def view_colour("client_events"), do: ComplexClientEventLib.colour()
  def view_colour("complex_server_events"), do: ComplexServerEventLib.colour()
  def view_colour("match_events"), do: SimpleMatchEventLib.colour()
  def view_colour("complex_match_events"), do: ComplexMatchEventLib.colour()
end
