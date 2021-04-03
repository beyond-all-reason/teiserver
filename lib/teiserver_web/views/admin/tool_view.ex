defmodule TeiserverWeb.Admin.ToolView do
  use TeiserverWeb, :view

  def colours, do: Central.Admin.ToolLib.colours()
  def icon, do: Central.Admin.ToolLib.icon()
end
