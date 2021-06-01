defmodule TeiserverWeb.Admin.ToolView do
  use TeiserverWeb, :view

  def colours, do: Central.Admin.ToolLib.colours()
  def icon, do: Central.Admin.ToolLib.icon()

  # For the detail view in day metrics
  def heatmap(value, maximum, colour) do
    CentralWeb.Logging.AggregateViewLogView.heatmap(value, maximum, colour)
  end

  def represent_minutes(s) do
    now = Timex.now()
    until = Timex.shift(now, minutes: s)
    time_until(until, now)
  end
end
