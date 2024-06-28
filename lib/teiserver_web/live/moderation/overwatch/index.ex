defmodule TeiserverWeb.Moderation.OverwatchLive.Index do
  use TeiserverWeb, :live_view
  alias Teiserver.{Moderation}
  alias Teiserver.Moderation.ReportLib

  @impl true
  def mount(params, _session, socket) do
    socket =
      socket
      |> assign(:site_menu_active, "moderation")
      |> assign(:view_colour, Teiserver.Moderation.colour())
      |> assign(:outstanding_report_groups, 0)
      |> assign(:report_groups, nil)
      |> default_filters(params)
      |> add_breadcrumb(name: "Moderation", url: ~p"/moderation")
      |> add_breadcrumb(name: "Overwatch", url: ~p"/moderation/overwatch")

    socket =
      if connected?(socket) do
        socket
        |> recalculate_outstanding_report_groups
      else
        socket
      end

    {:ok, socket}
  end

  # @impl true
  # def handle_params(params, _url, socket) do
  #   {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  # end

  # defp apply_action(socket, _live_action, _params) do
  #   socket
  # end

  @impl true
  def handle_event("filter-update", event, %{assigns: %{filters: filters}} = socket) do
    [key] = event["_target"]
    value = event[key]

    new_filters = Map.put(filters, key, value)

    socket =
      socket
      |> assign(:filters, new_filters)
      |> recalculate_outstanding_report_groups

    {:noreply, socket}
  end

  defp default_filters(socket, params) do
    filters =
      Map.merge(
        %{
          "actioned-filter" => "All",
          "closed-filter" => "Open",
          "kind-filter" => "Any",
          "timeframe-filter" => "standard",
          "target_id" => Map.get(params, "target_id")
        },
        socket.assigns[:filters] || %{}
      )

    socket
    |> assign(:filters, filters)
  end

  defp recalculate_outstanding_report_groups(
         %{assigns: %{current_user: _current_user, filters: filters}} = socket
       ) do
    closed_filter =
      case filters["closed-filter"] do
        "Open" -> false
        "Closed" -> true
        _ -> nil
      end

    actioned_filter =
      case filters["actioned-filter"] do
        "Actioned" -> true
        "Un-actioned" -> false
        _ -> nil
      end

    timeframe =
      case filters["timeframe-filter"] do
        "standard" -> Timex.shift(Timex.now(), days: -ReportLib.get_outstanding_report_max_days())
        "all" -> nil
        _ -> nil
      end

    kind =
      case filters["kind-filter"] do
        "Any" -> nil
        "Actions" -> "actions"
        "Chat" -> "chat"
      end

    report_groups =
      Moderation.list_report_groups(
        where: [
          closed: closed_filter,
          actioned: actioned_filter,
          inserted_after: timeframe,
          has_reports_of_kind: kind,
          target_id: filters["target_id"]
        ],
        order_by: ["Newest first"],
        limit: 50,
        preload: [:target]
      )

    socket
    |> assign(:report_groups, report_groups)
  end
end
