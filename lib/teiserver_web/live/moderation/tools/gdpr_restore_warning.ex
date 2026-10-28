defmodule TeiserverWeb.ModerationLive.Tools.GDPRRestoreWarning do
  @moduledoc false
  alias TeiserverWeb.ModerationLive.ToolsComponents

  use TeiserverWeb, :live_view

  @impl LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl LiveView
  def handle_params(_params, _url, socket) do
    socket
    |> assign(page_title: "GDPR account restoration")
    |> noreply()
  end

  @impl LiveView
  def render(assigns) do
    ~H"""
    <ToolsComponents.section_menu active="gdpr_restore" scope={@scope} />

    <div class="single-block-content bg-warning/80 text-warning-content p-10 px-30">
      <h1 class="text-center text-4xl font-bold">GDPR account restoration</h1>
      <p class="py-6" id="warning-text">
        All access beyond this point is logged and reviewed. Account restoration should only ever be performed as part of a specific request.
      </p>
      <div class="p-6 m-4 text-lg text-left"></div>

      <div class="flex">
        <div class="flex-1 px-2">
          <a href={~p"/moderation"} class="btn btn-lg btn-neutral w-full">
            Cancel
          </a>
        </div>
        <div class="flex-1 px-2">
          <a
            href={~p"/moderation/tools/gdpr_restore/perform"}
            class="btn btn-primary btn-lg w-full"
          >
            Proceed to restoration
          </a>
        </div>
      </div>
    </div>
    """
  end
end
