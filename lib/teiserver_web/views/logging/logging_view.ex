defmodule TeiserverWeb.Logging.LoggingView do
  use TeiserverWeb, :view

  def view_colour(), do: Teiserver.Helper.StylingHelper.colours(:info)
  def icon(), do: "fa-solid fa-chart-line"
end
