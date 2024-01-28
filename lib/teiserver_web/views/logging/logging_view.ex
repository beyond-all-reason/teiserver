defmodule BarserverWeb.Logging.LoggingView do
  use BarserverWeb, :view

  def view_colour(), do: Barserver.Helper.StylingHelper.colours(:info)
  def icon(), do: "fa-regular fa-chart-line"
end
