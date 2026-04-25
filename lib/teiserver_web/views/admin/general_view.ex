defmodule TeiserverWeb.Admin.GeneralView do
  alias Teiserver.Account.AccoladeLib
  alias Teiserver.Account.BadgeTypeLib
  alias Teiserver.Account.CodeLib
  alias Teiserver.Account.UserLib
  alias Teiserver.Admin.ToolLib
  alias Teiserver.Battle.MatchLib
  alias Teiserver.Chat.LobbyMessageLib
  alias Teiserver.Clans.ClanLib
  alias Teiserver.Communication.DiscordChannelLib
  alias Teiserver.Communication.TextCallbackLib
  alias Teiserver.Config.SiteConfigLib
  alias Teiserver.Game.AchievementTypeLib
  alias Teiserver.OAuth.ApplicationLib
  alias Teiserver.Telemetry.TelemetryLib

  use TeiserverWeb, :view

  @spec view_colour() :: atom
  def view_colour, do: :info

  @spec icon() :: String.t()
  def icon, do: StylingHelper.icon(:info)

  @spec view_colour(String.t()) :: atom()
  def view_colour("clans"), do: ClanLib.colours()
  def view_colour("users"), do: UserLib.colours()
  def view_colour("telemetry"), do: TelemetryLib.colours()
  def view_colour("tools"), do: ToolLib.colours()
  def view_colour("chat"), do: LobbyMessageLib.colours()
  def view_colour("accolades"), do: AccoladeLib.colours()
  def view_colour("matches"), do: MatchLib.colours()
  def view_colour("badge_types"), do: BadgeTypeLib.colours()
  def view_colour("text_callbacks"), do: TextCallbackLib.colours()
  def view_colour("discord_channels"), do: DiscordChannelLib.colours()
  def view_colour("achievements"), do: AchievementTypeLib.colour()
  def view_colour("config"), do: SiteConfigLib.colours()
  def view_colour("tool"), do: ToolLib.colours()
  def view_colour("codes"), do: CodeLib.colours()
  def view_colour("oauth_applications"), do: ApplicationLib.colours()
end
