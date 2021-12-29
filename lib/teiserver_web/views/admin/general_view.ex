defmodule TeiserverWeb.Admin.GeneralView do
  use TeiserverWeb, :view

  @spec colours() :: {String.t(), String.t(), String.t()}
  def colours(), do: StylingHelper.colours(:info)
  @spec icon() :: String.t()
  def icon(), do: StylingHelper.icon(:info)

  @spec colours(String.t()) :: {String.t(), String.t(), String.t()}
  def colours("clans"), do: Teiserver.Clans.ClanLib.colours()
  def colours("users"), do: Teiserver.Account.UserLib.colours()
  def colours("queues"), do: Teiserver.Game.QueueLib.colours()
  def colours("telemetry"), do: Teiserver.Telemetry.TelemetryLib.colours()
  def colours("tools"), do: Central.Admin.ToolLib.colours()
  def colours("ban_hashes"), do: Teiserver.Account.BanHashLib.colours()
  def colours("chat"), do: Central.Communication.CommentLib.colours()
  def colours("accolades"), do: Teiserver.Account.AccoladeLib.colours()
  def colours("matches"), do: Teiserver.Battle.MatchLib.colours()
  def colours("badge_types"), do: Teiserver.Account.BadgeTypeLib.colours()
end
