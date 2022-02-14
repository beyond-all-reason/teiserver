defmodule CentralWeb.Logging.LoggingView do
  use CentralWeb, :view

  def view_colour(), do: :info
  def icon(), do: "far fa-chart-line"
end
