defmodule TeiserverWeb.Moderation.OverwatchLive.ReportGroupDetail do
  use TeiserverWeb, :live_view
  alias Teiserver.{Moderation}
  alias Teiserver.Moderation.ReportGroupLib

  @impl true
  def mount(%{"id" => id_str}, _session, socket) when is_connected?(socket) do
    id = String.to_integer(id_str)
    socket = default_mount(socket)

    report_group = get_report_group(id)

    report_group
    |> ReportGroupLib.make_favourite()
    |> insert_recently(socket)

    # TODO also assign reporter info here, it's needed for report authors and chat link

    socket =
      socket
      |> assign(:report_group, report_group)
      |> add_breadcrumb(
        name: "Report group #{report_group.id}",
        url: ~p"/moderation/overwatch/report_group/#{id}"
      )

    {:ok, socket}
  end

  def mount(%{"id" => _id_str}, _session, socket) do
    {:ok, default_mount(socket)}
  end

  defp default_mount(socket) do
    socket
    |> assign(:site_menu_active, "moderation")
    |> assign(:view_colour, Teiserver.Moderation.colour())
    |> assign(:report_group, nil)
    |> add_breadcrumb(name: "Moderation", url: ~p"/moderation")
    |> add_breadcrumb(name: "Overwatch", url: ~p"/moderation/overwatch")
  end

  @impl true
  #  def handle_event("filter-update", event, %{assigns: %{filters: filters}} = socket) do
  #    [key] = event["_target"]
  #    value = event[key]
  #
  #    new_filters = Map.put(filters, key, value)
  #
  #    socket =
  #      socket
  #      |> assign(:filters, new_filters)
  #
  #    {:noreply, socket}
  #  end

  def handle_event("close-group", _event, %{assigns: %{report_group: report_group}} = socket) do
    {:ok, _} = Moderation.update_report_group(report_group, %{"closed" => "true"})

    {:noreply,
     socket
     |> assign(:report_group, get_report_group(report_group.id))}
  end

  def handle_event("open-group", _event, %{assigns: %{report_group: report_group}} = socket) do
    {:ok, _} = Moderation.update_report_group(report_group, %{"closed" => "false"})

    {:noreply,
     socket
     |> assign(:report_group, get_report_group(report_group.id))}
  end

  defp get_report_group(id) do
    Moderation.get_report_group!(id, preload: [:reports, :targets, :actions])
  end
end
