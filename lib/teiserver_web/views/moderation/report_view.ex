defmodule TeiserverWeb.Moderation.ReportView do
  alias Teiserver.Moderation.ReportLib

  use TeiserverWeb, :view

  import TeiserverWeb.PaginationComponents, only: [pagination: 1]

  @spec view_colour() :: atom
  def view_colour, do: ReportLib.colour()

  @spec icon() :: String.t()
  def icon, do: ReportLib.icon()
end
