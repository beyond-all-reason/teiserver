defmodule TeiserverWeb.Admin.ToolView do
  use TeiserverWeb, :view

  def view_colour, do: Teiserver.Admin.ToolLib.colours()
  def icon, do: Teiserver.Admin.ToolLib.icon()
end
