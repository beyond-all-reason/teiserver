defmodule TeiserverWeb.Logging.PageViewLogView do
  alias Teiserver.Logging.PageViewLogLib

  use TeiserverWeb, :view

  def view_colour(), do: PageViewLogLib.colours()
  def icon(), do: PageViewLogLib.icon()

  def convert_load_time(load_time) do
    round(load_time / 10) / 100
  end
end
