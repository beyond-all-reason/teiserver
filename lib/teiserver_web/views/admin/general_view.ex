defmodule BarserverWeb.Admin.GeneralView do
  use BarserverWeb, :view

  @spec view_colour() :: atom
  def view_colour(), do: :info

  @spec icon() :: String.t()
  def icon(), do: StylingHelper.icon(:info)

  @spec view_colour(String.t()) :: atom()
  def view_colour("clans"), do: Barserver.Clans.ClanLib.colours()
  def view_colour("users"), do: Barserver.Account.UserLib.colours()
  def view_colour("queues"), do: Barserver.Game.QueueLib.colours()
  def view_colour("telemetry"), do: Barserver.Telemetry.TelemetryLib.colours()
  def view_colour("tools"), do: Barserver.Admin.ToolLib.colours()
  def view_colour("chat"), do: Barserver.Chat.LobbyMessageLib.colours()
  def view_colour("accolades"), do: Barserver.Account.AccoladeLib.colours()
  def view_colour("lobby_policies"), do: Barserver.Game.LobbyPolicyLib.colours()
  def view_colour("matches"), do: Barserver.Battle.MatchLib.colours()
  def view_colour("badge_types"), do: Barserver.Account.BadgeTypeLib.colours()
  def view_colour("text_callbacks"), do: Barserver.Communication.TextCallbackLib.colours()
  def view_colour("discord_channels"), do: Barserver.Communication.DiscordChannelLib.colours()
  def view_colour("achievements"), do: Barserver.Game.AchievementTypeLib.colour()
  def view_colour("config"), do: Barserver.Config.SiteConfigLib.colours()
  def view_colour("tool"), do: Barserver.Admin.ToolLib.colours()
  def view_colour("codes"), do: Barserver.Account.CodeLib.colours()
end
