defmodule BarserverWeb.Logging.ServerLogView do
  use BarserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: Barserver.Logging.ServerDayLogLib.colours()

  @spec icon() :: String.t()
  def icon(), do: Barserver.Logging.ServerDayLogLib.icon()

  # For the detail view in day metrics
  def heatmap(value, maximum, colour) do
    BarserverWeb.Logging.AggregateViewLogView.heatmap(value, maximum, colour)
  end
end
