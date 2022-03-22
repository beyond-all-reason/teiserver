defmodule CentralWeb.Logging.LoggingView do
  use CentralWeb, :view

  def view_colour(), do: Central.Helpers.StylingHelper.colours(:info)
  def icon(), do: "fa-regular fa-chart-line"
end
