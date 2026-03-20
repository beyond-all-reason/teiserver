defmodule TeiserverWeb.Logging.MatchLogView do
  alias Teiserver.Battle.MatchLib
  alias TeiserverWeb.Logging.AggregateViewLogView

  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour, do: MatchLib.colours()

  @spec icon() :: String.t()
  def icon, do: MatchLib.icon()

  # For the detail view in day metrics
  def heatmap(value, maximum, colour) do
    AggregateViewLogView.heatmap(value, maximum, colour)
  end
end
