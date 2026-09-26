defmodule TeiserverWeb.StaffLive.Menu do
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
        icon={Teiserver.Communication.TextCallbackLib.icon()}
        url={~p"/staff/text_callbacks"}
      >
        Discord commands
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
