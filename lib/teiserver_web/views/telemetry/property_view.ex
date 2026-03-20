defmodule TeiserverWeb.Telemetry.PropertyView do
  alias Teiserver.Telemetry.PropertyTypeLib

  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: PropertyTypeLib.colours()

  @spec icon() :: String.t()
  def icon(), do: PropertyTypeLib.icon()
end
