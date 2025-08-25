defmodule TeiserverWeb.Battle.MatchLive.Index do
  use TeiserverWeb, :live_view
  alias Teiserver.{Account, Battle}
  import TeiserverWeb.PaginationComponents, only: [pagination: 1]

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
      |> default_pagination()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    page = (params["page"] || "1") |> String.to_integer() |> max(1) |> then(&(&1 - 1))
    limit = (params["limit"] || "25") |> String.to_integer() |> max(1)
    
    # Update filters from URL params
    updated_filters = 
      socket.assigns.filters
      |> Map.put("game-type", params["game-type"] || socket.assigns.filters["game-type"])
      |> Map.put("opponent", params["opponent"] || socket.assigns.filters["opponent"])
      |> Map.put("ally", params["ally"] || socket.assigns.filters["ally"])

    socket =
      socket
      |> assign(:page, page)
      |> assign(:limit, limit)
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
      |> push_patch(to: build_url(%{filters: new_filters, limit: socket.assigns.limit}))

    {:noreply, socket}
  end

  defp update_match_list(%{assigns: %{filters: filters, current_user: current_user, page: page, limit: limit}} = socket) do
    if connected?(socket) do
      {matches, total_count} = run_match_query(filters, current_user, page, limit)
      total_pages = max(1, div(total_count - 1, limit) + 1)

      socket
      |> assign(:matches, matches)
      |> assign(:total_count, total_count)
      |> assign(:total_pages, total_pages)
      |> assign(:current_count, Enum.count(matches))
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

    # Get total count
    total_count = Battle.count_matches(search: search_criteria)

    # Get paginated matches
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

  defp default_pagination(socket) do
    socket
    |> assign(:page, 0)
    |> assign(:limit, 25)
    |> assign(:total_count, 0)
    |> assign(:total_pages, 1)
    |> assign(:current_count, 0)
  end

  defp build_url(opts) do
    base_params = %{
      "game-type" => opts.filters["game-type"],
      "opponent" => opts.filters["opponent"],
      "ally" => opts.filters["ally"],
      "limit" => opts.limit
    }
    
    # Remove empty values and defaults
    params = Enum.reject(base_params, fn {k, v} -> 
      v == "" or v == "Any type" or (k == "limit" and v == 25)
    end)
    
    query_string = 
      params
      |> Enum.map(fn {k, v} -> "#{k}=#{URI.encode_www_form(to_string(v))}" end)
      |> Enum.join("&")
    
    if query_string == "" do
      "/battle?dummy=1"
    else
      "/battle?#{query_string}"
    end
  end
end
