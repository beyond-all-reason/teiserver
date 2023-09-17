defmodule TeiserverWeb.Moderation.OverwatchLive.ReportGroupDetail do
  use TeiserverWeb, :live_view
  alias Teiserver.{Moderation}
  alias Teiserver.Moderation.ReportGroupLib

  @impl true
  def mount(%{"id" => id_str}, _session, socket) when is_connected?(socket) do
    id = String.to_integer(id_str)
    socket = default_mount(socket, id)

    report_group = Moderation.get_report_group!(id, preload: [:target, :actions])

    report_group
      |> ReportGroupLib.make_favourite()
      |> insert_recently(socket)

    socket = socket
      |> assign(:report_group, report_group)

    {:ok, socket}
  end

  def mount(%{"id" => id_str}, _session, socket) do
    id = String.to_integer(id_str)
    {:ok, default_mount(socket, id)}
  end

  defp default_mount(socket, id) do
    socket
      |> assign(:site_menu_active, "moderation")
      |> assign(:view_colour, Teiserver.Moderation.colour())
      |> assign(:report_group, nil)
      |> add_breadcrumb(name: "Moderation", url: ~p"/moderation")
      |> add_breadcrumb(name: "Overwatch", url: ~p"/moderation/overwatch")
      |> add_breadcrumb(name: "Report group ##{id}", url: ~p"/moderation/overwatch/report_group/#{id}")
  end

  @impl true
  def handle_event("filter-update", event, %{assigns: %{filters: filters}} = socket) do
    [key] = event["_target"]
    value = event[key]

    new_filters = Map.put(filters, key, value)

    socket = socket
      |> assign(:filters, new_filters)

    {:noreply, socket}
  end
end
