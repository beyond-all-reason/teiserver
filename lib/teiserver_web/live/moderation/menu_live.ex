defmodule TeiserverWeb.ModerationLive.Menu do
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
        icon={Teiserver.Moderation.ReportLib.icon()}
        icon_class="fa-solid"
        url={~p"/moderation/report"}
      >
        Reports
      </.menu_page_link>

      <.menu_page_link
        icon={Teiserver.Moderation.ActionLib.icon()}
        icon_class="fa-solid"
        url={~p"/moderation/action"}
      >
        Actions
      </.menu_page_link>

      <.menu_page_link
        icon={Teiserver.Moderation.BanLib.icon()}
        icon_class="fa-solid"
        url={~p"/moderation/ban"}
      >
        Bans
      </.menu_page_link>

      <.menu_page_link
        :if={allow?(@scope, "Moderator")}
        icon="users"
        url={~p"/moderation/users"}
      >
        Users
      </.menu_page_link>

      <.menu_page_link
        :if={allow?(@scope, "Moderator")}
        icon="text-slash"
        url={~p"/moderation/banned_phrases"}
      >
        Banned Phrases
      </.menu_page_link>

      <.menu_page_link
        :if={allow?(@scope, "Moderator")}
        icon="globe"
        url={~p"/moderation/banned_domains"}
      >
        Banned domains
      </.menu_page_link>

      <.menu_page_link
        :if={allow?(@scope, "Moderator")}
        icon="location-dot"
        url={~p"/moderation/banned_ips"}
      >
        Banned IPs
      </.menu_page_link>
    </div>

    <div class="menu-grid">
      <.menu_page_link
        :if={allow?(@scope, "Moderator")}
        icon="fa-code-compare"
        url={~p"/moderation/tools/time_compare"}
      >
        Time compare
      </.menu_page_link>
    </div>

    <div class="menu-grid">
      <.menu_page_link icon={StylingHelper.icon(:back)} url={~p"/"} size={:small}>
        Back
      </.menu_page_link>
    </div>
    """
  end
end
