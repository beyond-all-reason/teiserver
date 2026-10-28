defmodule TeiserverWeb.ModerationLive.AntiAbuseRecord.Warning do
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
    <div class="single-block-content bg-warning/80 text-warning-content p-10 px-30">
      <h1 class="text-center text-4xl font-bold">
        <Fontawesome.icon icon="triangle-exclamation" /> Anti-abuse records
      </h1>
      <p class="py-6" id="warning-text">
        All access beyond this point is logged and reviewed. Anti-abuse records should only ever be viewed for a specific reason.
      </p>
      <a href={~p"/admin"} class="btn btn-neutral">
        <Fontawesome.icon icon="fa-arrow-left" /> Back to admin
      </a>

      <a href={~p"/moderation/anti-abuse-records/list"} class="btn btn-primary float-right">
        <Fontawesome.icon icon="fa-arrow-right" /> Proceed to records
      </a>
    </div>
    """
  end
end
