defmodule TeiserverWeb.Battle.MatchLive.Index do
  use TeiserverWeb, :live_view
  alias Teiserver.{Account, Battle}

  @impl true
  def mount(_params, _ession, socket) do
    game_types = ["Any type" | Teiserver.Battle.MatchLib.list_game_types]

    socket = socket
      |> assign(:site_menu_active, "match")
      |> assign(:view_colour, Teiserver.Battle.MatchLib.colours())
      |> assign(:game_types, game_types)
      |> default_filters()
      |> update_match_list()

    {:ok, socket}
  end

  @impl true
  def handle_event("filter-update", event, %{assigns: %{filters: filters}} = socket) do
    [key] = event["_target"]
    value = event[key]

    new_filters = Map.put(filters, key, value)

    socket = socket
      |> assign(:filters, new_filters)
      |> update_match_list

    {:noreply, socket}
  end

  defp update_match_list(%{assigns: %{filters: filters, current_user: current_user}} = socket) do
    if connected?(socket) do
      matches = run_match_query(filters, current_user)

      if matches != nil do
        socket
        |> assign(:matches, matches)
      else
        socket
      end
    else
      socket
      |> assign(:matches, [])
    end
  end

  defp update_match_list(socket) do
    socket
  end

  defp run_match_query(filters, user) do
    opponent_id = if filters["opponent"] != "" do
      Account.get_userid_from_name(filters["opponent"]) || -1
    else
      nil
    end

    ally_id = if filters["ally"] != "" do
      Account.get_userid_from_name(filters["ally"]) || -1
    else
      nil
    end

    matches = Battle.list_matches(
      search: [
        has_started: true,
        # user_id: user.id,
        game_type: filters["game-type"],
        ally_opponent: {user.id, ally_id, opponent_id}
      ],
      preload: [
        :queue
      ],
      order_by: "Newest first"
    )

    matches
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
