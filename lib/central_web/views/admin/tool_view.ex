defmodule CentralWeb.Admin.ToolView do
  use CentralWeb, :view

  def view_colour(), do: Central.Admin.ToolLib.colours()
  def icon(), do: Central.Admin.ToolLib.icon()

  def uptime() do
    System.cmd("uptime", [])
    |> elem(0)
    |> String.trim
  end

  def view_colour(_), do: Central.Admin.ToolLib.colours()
end
