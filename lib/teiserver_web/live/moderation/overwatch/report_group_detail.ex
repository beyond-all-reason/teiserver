defmodule TeiserverWeb.Moderation.OverwatchLive.ReportGroupDetail do
  use TeiserverWeb, :live_view
  alias Teiserver.{Moderation}
  alias Teiserver.Moderation.ReportGroupLib
  import TeiserverWeb.Moderation.ReportGroupActions

  @impl true
  def mount(%{"id" => id_str}, _session, socket) when is_connected?(socket) do
    id = String.to_integer(id_str)
    socket = default_mount(socket)

    report_group = get_report_group(id)

    report_group
    |> Map.update!(:reports, fn reports ->
      Enum.sort_by(reports, & &1.target.id, &<=/2)
    end)
    |> ReportGroupLib.make_favourite()
    |> insert_recently(socket)

    targets =
      report_group.reports
      # get all targets
      |> Enum.map(& &1.target)
      # remove duplicates
      |> Enum.uniq_by(& &1.id)
      # sort by id ascending
      |> Enum.sort_by(& &1.id, &<=/2)

    # TODO also assign reporter info here, it's needed for report authors and chat link

    socket =
      socket
      |> assign(:report_group, report_group)
      |> assign(:targets, targets)
      |> assign(:show_menu, %{})
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
    Moderation.close_report_group(report_group)

    {:noreply,
     socket
     |> assign(:report_group, get_report_group(report_group.id))}
  end

  def handle_event("open-group", _event, %{assigns: %{report_group: report_group}} = socket) do
    Moderation.open_report_group(report_group)

    {:noreply,
     socket
     |> assign(:report_group, get_report_group(report_group.id))}
  end

  def handle_event("toggle_dropdown", %{"key" => key}, socket) do
    show_menu = Map.update(socket.assigns.show_menu, key, true, &(!&1))
    {:noreply, assign(socket, show_menu: show_menu)}
  end

  def handle_event("close_all_dropdowns", _params, socket) do
    {:noreply, assign(socket, show_menu: %{})}
  end

  defp get_report_group(id) do
    Moderation.get_report_group!(id, preload: [:reports, :reporters, :targets, :actions])
  end

  @spec view_colour() :: atom
  def view_colour, do: Teiserver.Moderation.ReportLib.colour()
end
