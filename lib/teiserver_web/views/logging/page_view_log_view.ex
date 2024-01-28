defmodule BarserverWeb.Logging.PageViewLogView do
  use BarserverWeb, :view

  def view_colour(), do: Barserver.Logging.PageViewLogLib.colours()
  def icon(), do: Barserver.Logging.PageViewLogLib.icon()

  def convert_load_time(load_time) do
    round(load_time / 10) / 100
  end
end
