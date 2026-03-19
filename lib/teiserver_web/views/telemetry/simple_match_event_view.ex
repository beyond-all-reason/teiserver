defmodule TeiserverWeb.Telemetry.SimpleMatchEventView do
  use TeiserverWeb, :view

  alias Teiserver.Telemetry.SimpleMatchEventLib

  @spec view_colour :: atom
  def view_colour(), do: SimpleMatchEventLib.colour()

  @spec icon() :: String.t()
  def icon(), do: SimpleMatchEventLib.icon()
end
