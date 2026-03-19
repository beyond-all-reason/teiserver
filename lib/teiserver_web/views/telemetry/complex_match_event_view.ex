defmodule TeiserverWeb.Telemetry.ComplexMatchEventView do
  use TeiserverWeb, :view

  alias Teiserver.Telemetry.ComplexMatchEventLib

  @spec view_colour :: atom
  def view_colour(), do: ComplexMatchEventLib.colour()

  @spec icon() :: String.t()
  def icon(), do: ComplexMatchEventLib.icon()
end
