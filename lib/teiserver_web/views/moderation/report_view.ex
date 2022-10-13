defmodule TeiserverWeb.Moderation.ReportView do
  use TeiserverWeb, :view

  @spec view_colour() :: atom
  def view_colour, do: Teiserver.Moderation.ReportLib.colour()

  @spec icon() :: String.t()
  def icon, do: Teiserver.Moderation.ReportLib.icon()
end
