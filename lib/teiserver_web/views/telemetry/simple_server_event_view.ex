defmodule TeiserverWeb.Telemetry.SimpleServerEventView do
  use TeiserverWeb, :view

  alias Teiserver.Telemetry.SimpleServerEventLib

  @spec view_colour :: atom
  def view_colour(), do: SimpleServerEventLib.colour()

  @spec icon() :: String.t()
  def icon(), do: SimpleServerEventLib.icon()
end
