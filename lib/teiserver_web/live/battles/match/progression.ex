defmodule TeiserverWeb.Battle.MatchLive.Progression do
  use TeiserverWeb, :live_view
  alias Teiserver.{Account, Battle, Game}
  alias Teiserver.Game.MatchRatingLib
  alias Central.Helpers.TimexHelper

  @impl true
  def mount(params, _ession, socket) do
    game_types = Battle.MatchLib.list_rated_game_types()

    user_ratings =
      Account.list_ratings(
        search: [
          user_id: socket.assigns.current_user.id
        ],
        preload: [:rating_type]
      )
      |> Map.new(fn rating ->
        {rating.rating_type.name, rating}
      end)

    socket = socket
      |> assign(:site_menu_active, "match")
      |> assign(:view_colour, Battle.MatchLib.colours())
      |> assign(:game_types, game_types)
      |> assign(:user_ratings, user_ratings)
      |> assign(:rating_type, Map.get(params, "rating_type", "Team"))
      |> assign(:rating_type_list, MatchRatingLib.rating_type_list())
      |> assign(:rating_type_id_lookup, MatchRatingLib.rating_type_id_lookup())
      |> default_filters()
      |> update_match_list()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket = socket
      |> assign(:rating_type, Map.get(params, "rating_type", "Team"))
      |> update_match_list()

    {:noreply, socket}
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

  defp update_match_list(%{assigns: %{rating_type: rating_type, filters: filters, current_user: current_user}} = socket) do
    if connected?(socket) do
      data = run_match_query(filters, rating_type, current_user)

      if data != nil do
        socket
        |> assign(:data, data)
      else
        socket
      end
    else
      socket
      |> assign(:data, [])
    end
  end

  defp update_match_list(socket) do
    socket
  end

  defp run_match_query(filters, rating_type, user) do
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

    # matches = Battle.list_matches(
    #   search: [
    #     has_started: true,
    #     # user_id: user.id,
    #     game_type: filters["game-type"],
    #     ally_opponent: {user.id, ally_id, opponent_id}
    #   ],
    #   preload: [
    #     :queue
    #   ],
    #   order_by: "Newest first"
    # )


    filter_type_id = MatchRatingLib.rating_type_name_lookup()[rating_type] || 1

    logs =
      Game.list_rating_logs(
        search: [
          user_id: user.id,
          rating_type_id: filter_type_id
        ],
        order_by: "Newest first",
        limit: 50,
        preload: [:match, :match_membership]
      )

    data =
      logs
      |> List.foldl(%{}, fn rating, acc ->
        Map.update(
          acc,
          TimexHelper.date_to_str(rating.inserted_at, format: :ymd),
          {rating.value["skill"], rating.value["uncertainty"], rating.value["rating_value"], 1},
          fn {skill, uncertainty, rating_value, count} ->
            {skill + rating.value["skill"], uncertainty + rating.value["uncertainty"],
             rating_value + rating.value["rating_value"], count + 1}
          end
        )
      end)
      |> Enum.map(fn {date, {skill, uncertainty, rating_value, count}} ->
        %{
          date: date,
          rating_value: Float.round(rating_value / count, 2),
          skill: Float.round(skill / count, 2),
          uncertainty: Float.round(uncertainty / count, 2),
          count: count
        }
      end)
      |> Enum.sort_by(fn rating -> rating.date end)

    data
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
