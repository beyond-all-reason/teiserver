defmodule BarserverWeb.Report.ReportView do
  use BarserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: :danger

  @spec icon() :: String.t()
  def icon(), do: Barserver.Helper.StylingHelper.icon(:report)

  def mins_to_hours(nil), do: 0

  def mins_to_hours(t) do
    round(t / 60)
  end
end
