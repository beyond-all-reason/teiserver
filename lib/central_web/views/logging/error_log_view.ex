defmodule CentralWeb.Logging.ErrorLogView do
  use CentralWeb, :view

  def view_colour(), do: Central.Logging.ErrorLogLib.colours()
  def icon(), do: Central.Logging.ErrorLogLib.icon()
end
