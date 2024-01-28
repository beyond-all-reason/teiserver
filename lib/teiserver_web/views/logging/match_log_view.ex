defmodule BarserverWeb.Logging.MatchLogView do
  use BarserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: Barserver.Battle.MatchLib.colours()

  @spec icon() :: String.t()
  def icon(), do: Barserver.Battle.MatchLib.icon()

  # For the detail view in day metrics
  def heatmap(value, maximum, colour) do
    BarserverWeb.Logging.AggregateViewLogView.heatmap(value, maximum, colour)
  end
end
