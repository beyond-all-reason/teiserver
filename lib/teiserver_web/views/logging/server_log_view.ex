defmodule TeiserverWeb.Logging.ServerLogView do
  alias Teiserver.Logging.ServerDayLogLib
  alias TeiserverWeb.Logging.AggregateViewLogView

  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour, do: ServerDayLogLib.colours()

  @spec icon() :: String.t()
  def icon, do: ServerDayLogLib.icon()

  # For the detail view in day metrics
  def heatmap(value, maximum, colour) do
    AggregateViewLogView.heatmap(value, maximum, colour)
  end
end
