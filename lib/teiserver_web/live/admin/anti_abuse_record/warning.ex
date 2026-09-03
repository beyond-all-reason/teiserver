defmodule TeiserverWeb.Admin.AntiAbuseRecordLive.Warning do
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
    <div class="h-30">
      &nbsp;
    </div>
    <div class="hero">
      <div>
        <h1 class="text-4xl font-bold text-warning">
          <Fontawesome.icon icon="triangle-exclamation" /> Anti-abuse records
        </h1>
        <p class="py-6" id="warning-text">
          All access beyond this point is logged and reviewed. Anti-abuse records should only ever be viewed for a specific reason.
        </p>
        <a href={~p"/admin"} class="btn btn-secondary">
          <Fontawesome.icon icon="fa-arrow-left" /> Back to admin
        </a>

        <a href={~p"/admin/anti-abuse-records/list"} class="btn btn-warning float-right">
          <Fontawesome.icon icon="fa-arrow-right" /> Proceed to records
        </a>
      </div>
    </div>
    """
  end
end
