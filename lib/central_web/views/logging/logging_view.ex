defmodule CentralWeb.Logging.LoggingView do
  use CentralWeb, :view

  def colours(), do: {"#22AACC", "#EEFAFF", "info"}
  def icon(), do: "far fa-chart-line"
end
