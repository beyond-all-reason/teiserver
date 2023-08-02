defmodule TeiserverWeb.Logging.LoggingView do
  use TeiserverWeb, :view

  def view_colour(), do: Teiserver.Helper.StylingHelper.colours(:info)
  def icon(), do: "fa-regular fa-chart-line"
end
