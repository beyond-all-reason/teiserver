defmodule TeiserverWeb.Report.ClientEventView do
  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: Teiserver.Telemetry.ClientEventLib.colour()

  @spec icon() :: String.t()
  def icon(), do: Teiserver.Telemetry.ClientEventLib.icon()

  # For the detail view in day metrics
  def heatmap(value, maximum, colour) do
    TeiserverWeb.Logging.AggregateViewLogView.heatmap(value, maximum, colour)
  end

  def represent_minutes(nil), do: ""
  def represent_minutes(s) do
    now = Timex.now()
    until = Timex.shift(now, minutes: s)
    time_until(until, now)
  end

  def round(value, decimal_places) do
    dp_mult = :math.pow(10, decimal_places)
    round(value * dp_mult)/dp_mult
  end
end
