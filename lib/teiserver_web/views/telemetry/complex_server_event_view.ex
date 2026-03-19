defmodule TeiserverWeb.Telemetry.ComplexServerEventView do
  use TeiserverWeb, :view

  alias Teiserver.Telemetry.ComplexServerEventLib

  @spec view_colour :: atom
  def view_colour(), do: ComplexServerEventLib.colour()

  @spec icon() :: String.t()
  def icon(), do: ComplexServerEventLib.icon()
end
