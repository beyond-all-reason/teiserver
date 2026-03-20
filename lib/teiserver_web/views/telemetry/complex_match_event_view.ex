defmodule TeiserverWeb.Telemetry.ComplexMatchEventView do
  alias Teiserver.Telemetry.ComplexMatchEventLib

  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour, do: ComplexMatchEventLib.colour()

  @spec icon() :: String.t()
  def icon, do: ComplexMatchEventLib.icon()
end
