defmodule TeiserverWeb.Telemetry.InfologView do
  use TeiserverWeb, :view
  import TeiserverWeb.PaginationComponents, only: [pagination: 1]

  alias Teiserver.Telemetry.InfologLib

  @spec view_colour :: atom
  def view_colour(), do: InfologLib.colours()

  @spec icon() :: String.t()
  def icon(), do: InfologLib.icon()
end
