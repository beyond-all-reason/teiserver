defmodule TeiserverWeb.Moderation.GeneralView do
  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: :default

  @spec icon() :: String.t()
  def icon(), do: Teiserver.Moderation.ReportLib.icon()

  @spec view_colour(String.t()) :: atom
  def view_colour("actions"), do: Teiserver.Moderation.ActionLib.colour()
  def view_colour("reports"), do: Teiserver.Moderation.ReportLib.colour()
  def view_colour("proposals"), do: Teiserver.Moderation.ProposalLib.colour()
  def view_colour("bans"), do: Teiserver.Moderation.BanLib.colour()
end
