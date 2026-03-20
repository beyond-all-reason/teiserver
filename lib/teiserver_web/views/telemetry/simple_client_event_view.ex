defmodule TeiserverWeb.Telemetry.SimpleClientEventView do
  alias Teiserver.Telemetry.SimpleClientEventLib

  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: SimpleClientEventLib.colour()

  @spec icon() :: String.t()
  def icon(), do: SimpleClientEventLib.icon()
end
