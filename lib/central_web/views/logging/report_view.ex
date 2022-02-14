defmodule CentralWeb.Logging.ReportView do
  use CentralWeb, :view

  @spec view_colour() :: atom
  def view_colour(), do: :report

  @spec icon() :: String.t()
  def icon(), do: Central.Helpers.StylingHelper.icon(:report)
end
