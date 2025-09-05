defmodule TeiserverWeb.MapsLive.Index do
  use TeiserverWeb, :live_view
  alias Teiserver.Asset

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:site_menu_active, "maps")
      |> assign(:view_colour, :default)
      |> assign(:maps, [])
      |> assign(:filtered_maps, [])
      |> assign(:selected_queue, "all")
      |> assign(:available_queues, [])
      |> assign(:current_user, socket.assigns[:current_user])
      |> add_breadcrumb(name: "Maps", url: "/maps")
      |> load_maps()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    queue = params["queue"] || "all"

    socket =
      socket
      |> assign(:selected_queue, queue)
      |> apply_filter(queue)

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter-by-queue", %{"queue" => queue}, socket) do
    {:noreply, push_patch(socket, to: ~p"/maps?queue=#{queue}")}
  end

  defp load_maps(socket) do
    maps = Asset.get_all_maps()
    available_queues = extract_unique_queues(maps)

    socket
    |> assign(:maps, maps)
    |> assign(:available_queues, available_queues)
    |> apply_filter(socket.assigns.selected_queue)
  end

  defp apply_filter(socket, queue) do
    filtered_maps = filter_maps_by_queue(socket.assigns.maps, queue)
    assign(socket, :filtered_maps, filtered_maps)
  end

  defp filter_maps_by_queue(maps, "all") do
    maps
  end

  defp filter_maps_by_queue(maps, queue) do
    Enum.filter(maps, fn map ->
      queue in (map.matchmaking_queues || [])
    end)
  end

  defp extract_unique_queues(maps) do
    maps
    |> Enum.flat_map(fn map -> map.matchmaking_queues || [] end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  # Converts map display name to URL slug for beyondallreason.info/maps/:map pages
  defp map_display_name_to_url(display_name) do
    display_name
    |> String.downcase()
    |> String.replace(" ", "-")
  end
end
