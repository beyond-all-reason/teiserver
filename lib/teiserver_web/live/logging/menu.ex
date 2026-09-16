defmodule TeiserverWeb.LoggingLive.Menu do
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
        icon={Teiserver.Logging.ServerDayLogLib.icon()}
        url={~p"/logging/server"}
      >
        Server
      </.menu_page_link>

      <.menu_page_link
        icon={Teiserver.Battle.MatchLib.icon()}
        url={~p"/logging/match/day_metrics"}
      >
        Match
      </.menu_page_link>

      <.menu_page_link
        icon={Teiserver.Logging.PageViewLogLib.icon()}
        url={~p"/logging/page_views"}
      >
        Web
      </.menu_page_link>

      <.menu_page_link
        icon={Teiserver.Logging.AggregateViewLogLib.icon()}
        url={~p"/logging/aggregate_views"}
      >
        Web aggregate
      </.menu_page_link>

      <.menu_page_link
        icon={Teiserver.Logging.AuditLogLib.icon()}
        url={~p"/logging/audit_logs"}
      >
        Audit
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
