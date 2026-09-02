defmodule TeiserverWeb.Admin.MenuLive do
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
    <div class="grid grid-flow-row-dense grid-cols-8">
      <.menu_page_link
        :if={allow?(@scope, "Server")}
        icon="fa-gauge"
        url={~p"/admin/dashboard"}
      >
        Dashboard
      </.menu_page_link>

      <.menu_page_link
        :if={allow_any?(@current_user, ~w(Moderator Reviewer Overwatch))}
        icon={Teiserver.Moderation.icon()}
        url={~p"/moderation"}
      >
        Moderation
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
        Users
      </.menu_page_link>

      <.menu_page_link
        :if={allow_any?(@current_user, ~w(Reviewer))}
        icon={Teiserver.Chat.LobbyMessageLib.icon()}
        url={~p"/admin/chat"}
      >
        Chat
      </.menu_page_link>

      <.menu_page_link
        :if={allow_any?(@current_user, ~w(Contributor Overwatch))}
        icon={Teiserver.Helper.StylingHelper.icon(:summary)}
        url={~p"/teiserver/reports"}
      >
        Reports
      </.menu_page_link>

      <.menu_page_link
        :if={allow_any?(@current_user, ~w(Server Engine))}
        icon={Teiserver.Telemetry.TelemetryLib.icon()}
        url={~p"/telemetry"}
      >
        Telemetry
      </.menu_page_link>

      <.menu_page_link
        :if={allow?(@scope, "Admin")}
        icon={Teiserver.Logging.icon()}
        url={~p"/logging"}
      >
        Logging
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
        icon_class="fa-brands"
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

    <div class="grid grid-flow-row-dense grid-cols-8">
      <.menu_page_link icon={StylingHelper.icon(:back)} url={~p"/"} size={:small}>
        Back
      </.menu_page_link>
    </div>
    """
  end
end
