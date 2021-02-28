defmodule CentralWeb.Logging.PageViewLogView do
  use CentralWeb, :view

  def colours(), do: Central.Logging.PageViewLogLib.colours()
  def icon(), do: Central.Logging.PageViewLogLib.icon()

  def convert_load_time(load_time) do
    round(load_time / 10) / 100
  end
end
