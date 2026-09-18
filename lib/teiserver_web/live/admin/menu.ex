defmodule TeiserverWeb.AdminLive.Menu do
  @moduledoc false
  use TeiserverWeb, :live_view

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket
    |> ok()
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="menu-grid">
      <.menu_page_link
        :if={allow?(@scope, "Server")}
        icon="fa-gauge"
        url={~p"/admin/dashboard"}
      >
        Dashboard
      </.menu_page_link>

      <.menu_page_link
        :if={allow?(@current_user, "Senior moderator")}
        icon="person-burst"
        url={~p"/admin/anti-abuse-records"}
      >
        Anti-abuse records
      </.menu_page_link>

      <.menu_page_link
        :if={allow_any?(@current_user, ~w(Moderator))}
        icon={Teiserver.Account.UserLib.icon()}
        url={~p"/teiserver/admin/user"}
      >
        Users (Admin)
      </.menu_page_link>

      <.menu_page_link
        :if={allow_any?(@current_user, ~w(Moderator))}
        icon="users"
        url={~p"/moderation/users"}
      >
        Users (Moderation)
      </.menu_page_link>

      <.menu_page_link
        :if={allow_any?(@current_user, ~w(Reviewer))}
        icon={Teiserver.Chat.LobbyMessageLib.icon()}
        url={~p"/admin/chat"}
      >
        Chat
      </.menu_page_link>

      <.menu_page_link
        :if={allow_any?(@current_user, ~w(Server Engine))}
        icon={Teiserver.Telemetry.TelemetryLib.icon()}
        url={~p"/telemetry"}
      >
        Telemetry
      </.menu_page_link>

      <.menu_page_link
        :if={allow_any?(@current_user, ~w(Reviewer))}
        icon={Teiserver.Battle.MatchLib.icon()}
        url={~p"/teiserver/admin/matches"}
      >
        Matches
      </.menu_page_link>

      <.menu_page_link
        :if={allow_any?(@current_user, ~w(Admin))}
        icon="fa-solid fa-users"
        url={~p"/admin/matchmaking"}
      >
        Matchmaking
      </.menu_page_link>

      <.menu_page_link
        :if={allow_any?(@scope, ~w(Contributor Overwatch))}
        icon={Teiserver.Communication.TextCallbackLib.icon()}
        url={~p"/admin/text_callbacks"}
      >
        Text callbacks
      </.menu_page_link>

      <.menu_page_link
        :if={allow_any?(@scope, ~w(Server))}
        icon={Teiserver.Communication.DiscordChannelLib.icon()}
        url={~p"/admin/discord_channels"}
      >
        Discord channels
      </.menu_page_link>

      <.menu_page_link
        :if={allow_any?(@scope, ~w(Admin))}
        icon={Teiserver.OAuth.ApplicationLib.icon()}
        url={~p"/teiserver/admin/oauth_application"}
      >
        OAuth applications
      </.menu_page_link>

      <.menu_page_link
        :if={allow_any?(@scope, ~w(Admin))}
        icon={Teiserver.BotLib.icon()}
        url={~p"/teiserver/admin/bot"}
      >
        Bots
      </.menu_page_link>

      <.menu_page_link
        :if={allow_any?(@scope, ~w(Admin))}
        icon={Teiserver.AssetLib.icon()}
        url={~p"/teiserver/admin/asset"}
      >
        Engine & game versions
      </.menu_page_link>

      <.menu_page_link
        :if={allow_any?(@scope, ~w(Admin))}
        icon={Teiserver.Account.BadgeTypeLib.icon()}
        url={~p"/teiserver/admin/badge_types"}
      >
        Badge types
      </.menu_page_link>

      <.menu_page_link
        :if={allow_any?(@scope, ~w(Server))}
        icon={Teiserver.Account.CodeLib.icon()}
        url={~p"/teiserver/admin/codes"}
      >
        Codes
      </.menu_page_link>

      <.menu_page_link
        :if={allow_any?(@scope, ~w(Server))}
        icon={Teiserver.Config.SiteConfigLib.icon()}
        url={~p"/teiserver/admin/site"}
      >
        Site config
      </.menu_page_link>
    </div>

    <div class="menu-grid">
      <.menu_page_link
        :if={allow_any?(@scope, ~w(Admin))}
        icon="key"
        url={~p"/admin/tools/mfa_usage"}
      >
        MFA Usage
      </.menu_page_link>

      <.menu_page_link
        icon="list"
        url={~p"/admin/palette"}
      >
        Cmd Palette test
      </.menu_page_link>
    </div>

    <div class="menu-grid">
      <.menu_page_link icon={StylingHelper.icon(:back)} url={~p"/"}>
        Back
      </.menu_page_link>
    </div>
    """
  end
end
