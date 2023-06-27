defmodule TeiserverWeb.Logging.ServerLogView do
  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: Teiserver.Logging.ServerDayLogLib.colours()

  @spec icon() :: String.t()
  def icon(), do: Teiserver.Logging.ServerDayLogLib.icon()

  # For the detail view in day metrics
  def heatmap(value, maximum, colour) do
    TeiserverWeb.Logging.AggregateViewLogView.heatmap(value, maximum, colour)
  end
end
