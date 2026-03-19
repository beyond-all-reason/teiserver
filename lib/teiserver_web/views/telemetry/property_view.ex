defmodule TeiserverWeb.Telemetry.PropertyView do
  use TeiserverWeb, :view

  alias Teiserver.Telemetry.PropertyTypeLib

  @spec view_colour :: atom
  def view_colour(), do: PropertyTypeLib.colours()

  @spec icon() :: String.t()
  def icon(), do: PropertyTypeLib.icon()
end
