defmodule TeiserverWeb.Logging.ErrorLogView do
  use TeiserverWeb, :view

  def view_colour(), do: Teiserver.Logging.ErrorLogLib.colours()
  def icon(), do: Teiserver.Logging.ErrorLogLib.icon()
end
