defmodule TeiserverWeb.Moderation.OverwatchLive.Index do
  use TeiserverWeb, :live_view
  alias Teiserver.{Moderation}
  alias Teiserver.Moderation.ReportLib
  import TeiserverWeb.PaginationComponents, only: [pagination: 1, build_pagination_url: 4]

  @impl true
  def mount(params, _session, socket) do
    socket =
      socket
      |> assign(:site_menu_active, "moderation")
      |> assign(:view_colour, Teiserver.Moderation.colour())
      |> assign(:outstanding_report_groups, 0)
      |> assign(:report_groups, nil)
      |> assign(:page, 0)
      |> assign(:limit, 50)
      |> assign(:total_pages, 1)
      |> assign(:total_count, 0)
      |> assign(:current_count, 0)
      |> default_filters(params)
      |> add_breadcrumb(name: "Moderation", url: ~p"/moderation")
      |> add_breadcrumb(name: "Overwatch", url: ~p"/moderation/overwatch")

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    parsed = TeiserverWeb.Parsers.PaginationParams.parse_params(params)

    params =
      Map.merge(params, %{
        "limit" => parsed.limit,
        "page" => parsed.page
      })

    socket =
      socket
      |> default_filters(params)
      |> recalculate_outstanding_report_groups

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter-update", event, %{assigns: %{filters: filters}} = socket) do
    [key] = event["_target"]
    value = event[key]

    new_filters =
      filters
      |> Map.put(key, value)
      # Reset to first page when any filter changes
      |> Map.put("page", "1")

    socket =
      socket
      |> assign(:filters, new_filters)
      |> recalculate_outstanding_report_groups

    # Update URL to reflect the new filters and reset page to 1
    {:noreply,
     push_patch(socket,
       to:
         build_pagination_url(
           "/moderation/overwatch",
           new_filters,
           [
             "actioned-filter",
             "closed-filter",
             "kind-filter",
             "timeframe-filter",
             "target_id",
             "limit"
           ],
           %{"page" => "1"}
         )
     )}
  end

  def handle_event("page-change", %{"page" => page}, %{assigns: %{filters: filters}} = socket) do
    new_filters = Map.put(filters, "page", page)

    socket =
      socket
      |> assign(:filters, new_filters)
      |> recalculate_outstanding_report_groups

    {:noreply, socket}
  end

  def handle_event("limit-change", %{"limit" => limit}, %{assigns: %{filters: filters}} = socket) do
    new_filters =
      Map.put(filters, "limit", limit)
      # Reset to first page when changing limit
      |> Map.put("page", "1")

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
          "target_id" => Map.get(params, "target_id"),
          "page" => Map.get(params, "page", "1"),
          "limit" => Map.get(params, "limit", "50")
        },
        # Override defaults with URL parameters if they exist
        %{
          "actioned-filter" => Map.get(params, "actioned-filter"),
          "closed-filter" => Map.get(params, "closed-filter"),
          "kind-filter" => Map.get(params, "kind-filter"),
          "timeframe-filter" => Map.get(params, "timeframe-filter")
        }
        |> Enum.reject(fn {_k, v} -> is_nil(v) end)
        |> Map.new()
        |> Map.merge(socket.assigns[:filters] || %{})
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

    parsed = TeiserverWeb.Parsers.PaginationParams.parse_params(filters)
    page = parsed.page - 1
    limit = parsed.limit

    total_count =
      Moderation.count_report_groups(
        where: [
          closed: closed_filter,
          actioned: actioned_filter,
          inserted_after: timeframe,
          has_reports_of_kind: kind,
          target_id: filters["target_id"]
        ]
      )

    total_pages = ceil(total_count / limit) |> trunc()

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
        limit: limit,
        offset: page * limit,
        preload: [:target]
      )

    socket
    |> assign(:report_groups, report_groups)
    |> assign(:page, page)
    |> assign(:limit, limit)
    |> assign(:total_pages, total_pages)
    |> assign(:total_count, total_count)
    |> assign(:current_count, Enum.count(report_groups))
  end
end
