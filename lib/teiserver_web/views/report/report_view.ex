defmodule TeiserverWeb.Report.ReportView do
  use TeiserverWeb, :view

  @spec colours :: {String.t(), String.t(), String.t()}
  def colours(), do: Central.Helpers.StylingHelper.colours(:report)

  @spec icon() :: String.t()
  def icon(), do: Central.Helpers.StylingHelper.icon(:report)

  def mins_to_hours(nil), do: 0
  def mins_to_hours(t) do
    round(t/60)
  end

  def percent(v) do
    round(v * 100)
  end
end
