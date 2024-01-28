defmodule BarserverWeb.Moderation.GeneralView do
  use BarserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: :default

  @spec icon() :: String.t()
  def icon(), do: Barserver.Moderation.ReportLib.icon()

  @spec view_colour(String.t()) :: atom
  def view_colour("actions"), do: Barserver.Moderation.ActionLib.colour()
  def view_colour("reports"), do: Barserver.Moderation.ReportLib.colour()
  def view_colour("proposals"), do: Barserver.Moderation.ProposalLib.colour()
  def view_colour("bans"), do: Barserver.Moderation.BanLib.colour()
end
