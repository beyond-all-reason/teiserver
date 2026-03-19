defmodule TeiserverWeb.Telemetry.SimpleClientEventView do
  use TeiserverWeb, :view

  alias Teiserver.Telemetry.SimpleClientEventLib

  @spec view_colour :: atom
  def view_colour(), do: SimpleClientEventLib.colour()

  @spec icon() :: String.t()
  def icon(), do: SimpleClientEventLib.icon()
end
