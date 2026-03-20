defmodule TeiserverWeb.Telemetry.ComplexServerEventView do
  alias Teiserver.Telemetry.ComplexServerEventLib

  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour, do: ComplexServerEventLib.colour()

  @spec icon() :: String.t()
  def icon, do: ComplexServerEventLib.icon()
end
