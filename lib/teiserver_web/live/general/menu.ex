defmodule TeiserverWeb.GeneralLive.Menu do
  @moduledoc false
  alias Teiserver.Account.AuthLib

  use TeiserverWeb, :live_view

  @impl Phoenix.LiveView
  def mount(_params, _session, %Socket{assigns: %{current_user: user}} = socket) do
    mfa_warning? =
      AuthLib.mfa_required?() and AuthLib.contains_mfa_role?(user.roles) and
        not has_active_mfa?(user.id)

    socket
    |> assign(mfa_warning?: mfa_warning?)
    |> ok()
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div :if={@mfa_warning?} class="alert alert-warning">
      <a href={~p"/teiserver/account/security/totp"} class="btn btn-sm btn-neutral me-2">
        <i class="fa-fw fa-solid fa-lock"></i> &nbsp;
        Enable MFA
      </a>
      You have elevated privileges but do not have MFA enabled. The permissions are temporarily disabled until MFA is enabled.
    </div>

    <div class="menu-grid">
      <.menu_page_link
        :if={allow?(@current_user, "Contributor")}
        icon="fa-server"
        url={~p"/admin"}
      >
        Admin
      </.menu_page_link>

      <.menu_page_link
        :if={allow?(@current_user, "Overwatch")}
        icon={Teiserver.Moderation.icon()}
        url={~p"/moderation"}
      >
        Moderation
      </.menu_page_link>

      <.menu_page_link
        :if={allow?(@scope, "Admin")}
        icon={Teiserver.Logging.icon()}
        url={~p"/logging"}
      >
        Logging
      </.menu_page_link>

      <.menu_page_link
        :if={allow?(@current_user, "Contributor")}
        icon={StylingHelper.icon(:summary)}
        url={~p"/teiserver/reports"}
      >
        Reports
      </.menu_page_link>

      <.menu_page_link
        icon={Teiserver.Chat.RoomMessageLib.icon()}
        url={~p"/chat"}
      >
        Chat
      </.menu_page_link>

      <.menu_page_link icon={Teiserver.Lobby.icon()} url={~p"/battle/lobbies"}>
        Lobbies
      </.menu_page_link>

      <.menu_page_link icon={Teiserver.Battle.MatchLib.icon()} url={~p"/battle"}>
        Matches
      </.menu_page_link>

      <.menu_page_link icon={Teiserver.Microblog.icon()} url={~p"/microblog"}>
        Microblog
      </.menu_page_link>

      <.menu_page_link
        icon={Teiserver.Account.UserLib.icon()}
        url={~p"/profile"}
      >
        Account
      </.menu_page_link>

      <.menu_page_link
        icon={Teiserver.Account.RelationshipLib.icon()}
        url={~p"/account/relationship"}
      >
        Relationships
      </.menu_page_link>
    </div>

    <div class="menu-grid">
      <.link href={~p"/logout"} method="post" class="menu-link">
        <Fontawesome.icon icon="sign-out-alt" style="solid" size="4x" />
        <div class="mt-4 text-lg">Logout</div>
      </.link>
    </div>
    """
  end
end
