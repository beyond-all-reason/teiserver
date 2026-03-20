defmodule TeiserverWeb.Telemetry.SimpleServerEventView do
  alias Teiserver.Telemetry.SimpleServerEventLib

  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: SimpleServerEventLib.colour()

  @spec icon() :: String.t()
  def icon(), do: SimpleServerEventLib.icon()
end
