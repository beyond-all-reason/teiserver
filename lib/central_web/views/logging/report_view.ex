defmodule CentralWeb.Logging.ReportView do
  use CentralWeb, :view

  def colours(), do: Central.Helpers.StylingHelper.colours(:report)
  def icon(), do: Central.Helpers.StylingHelper.icon(:report)
end
