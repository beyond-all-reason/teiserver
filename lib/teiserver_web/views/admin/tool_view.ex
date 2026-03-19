defmodule TeiserverWeb.Admin.ToolView do
  use TeiserverWeb, :view

  alias Teiserver.Admin.ToolLib

  def view_colour, do: ToolLib.colours()
  def icon, do: ToolLib.icon()
end
