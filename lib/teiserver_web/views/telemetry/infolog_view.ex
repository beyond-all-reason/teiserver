defmodule TeiserverWeb.Telemetry.InfologView do
  alias Teiserver.Telemetry.InfologLib

  use TeiserverWeb, :view

  import TeiserverWeb.PaginationComponents, only: [pagination: 1]

  @spec view_colour :: atom
  def view_colour(), do: InfologLib.colours()

  @spec icon() :: String.t()
  def icon(), do: InfologLib.icon()
end
