defmodule TeiserverWeb.Telemetry.ComplexClientEventView do
  alias Teiserver.Telemetry.ComplexClientEventLib

  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: ComplexClientEventLib.colour()

  @spec icon() :: String.t()
  def icon(), do: ComplexClientEventLib.icon()
end
