defmodule TeiserverWeb.Logging.LoggingView do
  use TeiserverWeb, :view

  alias Teiserver.Helper.StylingHelper

  def view_colour(), do: StylingHelper.colours(:info)
  def icon(), do: "fa-solid fa-chart-line"
end
