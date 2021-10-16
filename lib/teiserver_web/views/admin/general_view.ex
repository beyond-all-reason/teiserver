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
  def colours("parties"), do: Teiserver.Game.PartyLib.colours()
  def colours("telemetry"), do: Teiserver.Telemetry.TelemetryLib.colours()
  def colours("tools"), do: Central.Admin.ToolLib.colours()
  def colours("ban_hashes"), do: Teiserver.Account.BanHashLib.colours()
  def colours("chat"), do: Central.Communication.CommentLib.colours()
end
