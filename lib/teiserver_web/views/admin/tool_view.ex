defmodule BarserverWeb.Admin.ToolView do
  use BarserverWeb, :view

  def view_colour, do: Barserver.Admin.ToolLib.colours()
  def icon, do: Barserver.Admin.ToolLib.icon()
end
