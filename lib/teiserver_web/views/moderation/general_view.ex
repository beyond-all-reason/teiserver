defmodule TeiserverWeb.Moderation.GeneralView do
  alias Teiserver.Moderation.ActionLib
  alias Teiserver.Moderation.BanLib
  alias Teiserver.Moderation.ReportLib

  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour, do: :default

  @spec icon() :: String.t()
  def icon, do: ReportLib.icon()

  @spec view_colour(String.t()) :: atom
  def view_colour("actions"), do: ActionLib.colour()
  def view_colour("reports"), do: ReportLib.colour()
  def view_colour("bans"), do: BanLib.colour()
end
