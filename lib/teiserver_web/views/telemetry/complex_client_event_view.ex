defmodule TeiserverWeb.Telemetry.ComplexClientEventView do
  use TeiserverWeb, :view

  alias Teiserver.Telemetry.ComplexClientEventLib

  @spec view_colour :: atom
  def view_colour(), do: ComplexClientEventLib.colour()

  @spec icon() :: String.t()
  def icon(), do: ComplexClientEventLib.icon()
end
