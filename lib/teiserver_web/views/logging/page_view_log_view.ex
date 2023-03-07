defmodule TeiserverWeb.Logging.PageViewLogView do
  use TeiserverWeb, :view

  def view_colour(), do: Teiserver.Logging.PageViewLogLib.colours()
  def icon(), do: Teiserver.Logging.PageViewLogLib.icon()

  def convert_load_time(load_time) do
    round(load_time / 10) / 100
  end
end
