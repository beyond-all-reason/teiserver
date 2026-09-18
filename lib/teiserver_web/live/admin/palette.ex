defmodule TeiserverWeb.AdminLive.Palette do
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
    <.live_component
      module={TeiserverWeb.LiveComponents.CmdPalette}
      id="cmd-palette"
      scope={@scope}
    />

    <div class="m-10">
      Hit Ctrl + K to bring up palette, it currently _only_ works on this page while we ensure it doesn't break anything else.
    </div>

    <div class="menu-grid">
      <.menu_page_link icon={StylingHelper.icon(:back)} url={~p"/"}>
        Back
      </.menu_page_link>
    </div>
    """
  end
end
