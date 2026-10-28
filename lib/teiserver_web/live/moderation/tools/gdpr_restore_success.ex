defmodule TeiserverWeb.ModerationLive.Tools.GDPRRestoreSuccess do
  @moduledoc false
  alias TeiserverWeb.ModerationLive.ToolsComponents

  use TeiserverWeb, :live_view

  @impl LiveView
  def mount(params, _session, socket) do
    socket
    |> assign(user_id: params["user_id"])
    |> ok()
  end

  @impl LiveView
  def handle_params(_params, _url, socket) do
    socket
    |> assign(page_title: "Account restored")
    |> noreply()
  end

  @impl LiveView
  def render(assigns) do
    ~H"""
    <ToolsComponents.section_menu active="gdpr_restore" scope={@scope} />

    <div class="single-block-content bg-success/80 text-success-content p-10 px-30">
      <h1 class="text-center text-4xl font-bold">Account restored</h1>
      <p class="py-6" id="success-text">
        The account has been successfully restored and will act like a normal account again. The Anti-Abuse record has been deleted as part of the restoration process.
      </p>
      <div class="p-6 m-4 text-lg text-left"></div>

      <div class="flex">
        <div class="flex-1 px-2">
          <a href={~p"/moderation"} class="btn btn-lg btn-neutral w-full">
            Back to Moderation
          </a>
        </div>
        <div class="flex-1 px-2">
          <a href={~p"/moderation/users/#{@user_id}"} class="btn btn-lg btn-primary w-full">
            View account
          </a>
        </div>
      </div>
    </div>
    """
  end
end
