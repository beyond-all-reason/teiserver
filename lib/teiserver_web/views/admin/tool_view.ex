defmodule TeiserverWeb.Admin.ToolView do
  use TeiserverWeb, :view

  def view_colour, do: Central.Admin.ToolLib.colours()
  def icon, do: Central.Admin.ToolLib.icon()
end
