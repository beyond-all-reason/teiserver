defmodule TeiserverWeb.GeneralLive.Palette do
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
      extra_commands={
        [
          # Examples of how extra commands would be added
          # TODO: Move these to the main module if the palette is included
          %{id: "goto:profile", cmd: :goto, label: "Goto: Profile", path: ~p"/profile"},
          %{id: "incomplete command", label: "incomplete command"}
        ]
      }
    />

    <div class="m-10">
      Hit Ctrl + K to bring up palette, it currently _only_ works on this page while we ensure it doesn't break anything else. Please let Teifion know your thoughts on it; in particular how it could be improved for you.
    </div>

    <div class="menu-grid">
      <.menu_page_link icon={StylingHelper.icon(:back)} url={~p"/"}>
        Back
      </.menu_page_link>
    </div>
    """
  end
end
