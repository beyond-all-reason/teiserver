defmodule TeiserverWeb.Admin.ToolView do
  alias Teiserver.Admin.ToolLib

  use TeiserverWeb, :view

  def view_colour, do: ToolLib.colours()
  def icon, do: ToolLib.icon()
end
