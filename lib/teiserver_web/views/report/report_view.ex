defmodule TeiserverWeb.Report.ReportView do
  use TeiserverWeb, :view

  @spec colours :: {String.t(), String.t(), String.t()}
  def colours(), do: Central.Helpers.StylingHelper.colours(:report)

  @spec icon() :: String.t()
  def icon(), do: Central.Helpers.StylingHelper.icon(:report)
end
