defmodule TeiserverWeb.Logging.LoggingView do
  alias Teiserver.Helper.StylingHelper

  use TeiserverWeb, :view

  def view_colour(), do: StylingHelper.colours(:info)
  def icon(), do: "fa-solid fa-chart-line"
end
