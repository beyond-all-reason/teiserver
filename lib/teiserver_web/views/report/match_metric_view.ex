defmodule TeiserverWeb.Report.MatchMetricView do
  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: Teiserver.Battle.MatchLib.colours()

  @spec icon() :: String.t()
  def icon(), do: Teiserver.Battle.MatchLib.icon()

  # For the detail view in day metrics
  def heatmap(value, maximum, colour) do
    CentralWeb.Logging.AggregateViewLogView.heatmap(value, maximum, colour)
  end

  def represent_minutes(nil), do: ""
  def represent_minutes(s) do
    now = Timex.now()
    until = Timex.shift(now, minutes: s)
    time_until(until, now)
  end

  def represent_seconds(nil), do: ""
  def represent_seconds(s) do
    now = Timex.now()
    until = Timex.shift(now, seconds: s)
    time_until(until, now)
  end

  def round(value, decimal_places) do
    dp_mult = :math.pow(10, decimal_places)
    round(value * dp_mult)/dp_mult
  end
end
