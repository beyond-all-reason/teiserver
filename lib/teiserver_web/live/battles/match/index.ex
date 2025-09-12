defmodule TeiserverWeb.Battle.MatchLive.Index do
  use TeiserverWeb, :live_view
  alias Teiserver.{Account, Battle}
  import TeiserverWeb.PaginationComponents, only: [pagination: 1, build_pagination_url: 4]

  @impl true
  def mount(_params, _session, socket) do
    game_types = ["Any type" | Teiserver.Battle.MatchLib.list_game_types()]

    socket =
      socket
      |> assign(:site_menu_active, "match")
      |> assign(:view_colour, Teiserver.Battle.MatchLib.colours())
      |> assign(:game_types, game_types)
      |> add_breadcrumb(name: "Matches", url: "/battle")
      |> default_filters()
      |> assign(:page, 0)
      |> assign(:limit, 100)
      |> assign(:total_count, 0)
      |> assign(:total_pages, 1)
      |> assign(:current_count, 0)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    parsed = TeiserverWeb.Parsers.PaginationParams.parse_params(params)

    # Update filters from URL params
    updated_filters =
      socket.assigns.filters
      |> Map.put("game-type", params["game-type"] || socket.assigns.filters["game-type"])
      |> Map.put("opponent", params["opponent"] || socket.assigns.filters["opponent"])
      |> Map.put("ally", params["ally"] || socket.assigns.filters["ally"])

    socket =
      socket
      |> assign(:page, parsed.page - 1)
      |> assign(:limit, parsed.limit)
      |> assign(:filters, updated_filters)
      |> update_match_list()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter-update", event, %{assigns: %{filters: filters}} = socket) do
    [key] = event["_target"]
    value = event[key]

    new_filters = Map.put(filters, key, value)

    # Reset to first page when filters change and update URL
    socket =
      socket
      |> assign(:page, 0)
      |> assign(:filters, new_filters)
      |> push_patch(
        to:
          build_pagination_url(
            "/battle",
            %{"limit" => socket.assigns.limit},
            ["limit"],
            new_filters
          )
      )
      |> update_match_list()

    {:noreply, socket}
  end

  defp update_match_list(
         %{assigns: %{filters: filters, current_user: current_user, page: page, limit: limit}} =
           socket
       ) do
    if connected?(socket) do
      case run_match_query(filters, current_user, page, limit) do
        {matches, total_count} when is_list(matches) and is_integer(total_count) ->
          socket
          |> assign(:matches, matches)
          |> assign(:total_count, total_count)
          |> assign(:total_pages, max(1, div(total_count - 1, limit) + 1))
          |> assign(:current_count, Enum.count(matches))

        _ ->
          # Fallback if query fails
          socket
          |> assign(:matches, [])
          |> assign(:total_count, 0)
          |> assign(:total_pages, 1)
          |> assign(:current_count, 0)
      end
    else
      socket
      |> assign(:matches, [])
      |> assign(:total_count, 0)
      |> assign(:total_pages, 1)
      |> assign(:current_count, 0)
    end
  end

  defp update_match_list(socket) do
    socket
  end

  defp run_match_query(filters, user, page, limit) do
    opponent_id =
      if filters["opponent"] != "" do
        Account.get_userid_from_name(filters["opponent"]) || -1
      else
        nil
      end

    ally_id =
      if filters["ally"] != "" do
        Account.get_userid_from_name(filters["ally"]) || -1
      else
        nil
      end

    search_criteria = [
      has_started: true,
      game_type: filters["game-type"],
      ally_opponent: {user.id, ally_id, opponent_id}
    ]

    total_count = Battle.count_matches(search: search_criteria)

    matches =
      Battle.list_matches(
        search: search_criteria,
        preload: [:queue],
        order_by: "Newest first",
        limit: limit,
        offset: page * limit
      )

    {matches, total_count}
  end

  defp default_filters(socket) do
    socket
    |> assign(:filters, %{
      "game-type" => "Any type",
      "opponent" => "",
      "ally" => ""
    })
  end
end
