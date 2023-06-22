defmodule TeiserverWeb.Report.ServerMetricView do
  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: Teiserver.Telemetry.ServerDayLogLib.colours()

  @spec icon() :: String.t()
  def icon(), do: Teiserver.Telemetry.ServerDayLogLib.icon()

  # For the detail view in day metrics
  def heatmap(value, maximum, colour) do
    TeiserverWeb.Logging.AggregateViewLogView.heatmap(value, maximum, colour)
  end
end
