defmodule TeiserverWeb.Report.MatchMetricView do
  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: Teiserver.Battle.MatchLib.colours()

  @spec icon() :: String.t()
  def icon(), do: Teiserver.Battle.MatchLib.icon()

  # For the detail view in day metrics
  def heatmap(value, maximum, colour) do
    TeiserverWeb.Logging.AggregateViewLogView.heatmap(value, maximum, colour)
  end
end
