defmodule TeiserverWeb.Telemetry.SimpleMatchEventView do
  alias Teiserver.Telemetry.SimpleMatchEventLib

  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: SimpleMatchEventLib.colour()

  @spec icon() :: String.t()
  def icon(), do: SimpleMatchEventLib.icon()
end
