defmodule BarserverWeb.Moderation.ReportView do
  use BarserverWeb, :view

  @spec view_colour() :: atom
  def view_colour, do: Barserver.Moderation.ReportLib.colour()

  @spec icon() :: String.t()
  def icon, do: Barserver.Moderation.ReportLib.icon()
end
