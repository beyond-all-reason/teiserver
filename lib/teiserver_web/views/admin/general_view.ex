defmodule TeiserverWeb.Admin.GeneralView do
  use TeiserverWeb, :view

  @spec view_colour() :: atom
  def view_colour(), do: :info

  @spec icon() :: String.t()
  def icon(), do: StylingHelper.icon(:info)

  @spec view_colour(String.t()) :: atom()
  def view_colour("clans"), do: Teiserver.Clans.ClanLib.colours()
  def view_colour("users"), do: Teiserver.Account.UserLib.colours()
  def view_colour("telemetry"), do: Teiserver.Telemetry.TelemetryLib.colours()
  def view_colour("tools"), do: Teiserver.Admin.ToolLib.colours()
  def view_colour("chat"), do: Teiserver.Chat.LobbyMessageLib.colours()
  def view_colour("accolades"), do: Teiserver.Account.AccoladeLib.colours()
  def view_colour("lobby_policies"), do: Teiserver.Game.LobbyPolicyLib.colours()
  def view_colour("matches"), do: Teiserver.Battle.MatchLib.colours()
  def view_colour("badge_types"), do: Teiserver.Account.BadgeTypeLib.colours()
  def view_colour("text_callbacks"), do: Teiserver.Communication.TextCallbackLib.colours()
  def view_colour("discord_channels"), do: Teiserver.Communication.DiscordChannelLib.colours()
  def view_colour("achievements"), do: Teiserver.Game.AchievementTypeLib.colour()
  def view_colour("config"), do: Teiserver.Config.SiteConfigLib.colours()
  def view_colour("tool"), do: Teiserver.Admin.ToolLib.colours()
  def view_colour("codes"), do: Teiserver.Account.CodeLib.colours()
  def view_colour("oauth_applications"), do: Teiserver.OAuth.ApplicationLib.colours()
end
