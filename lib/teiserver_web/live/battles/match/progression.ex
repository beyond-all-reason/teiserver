defmodule TeiserverWeb.Battle.MatchLive.Progression do
  use TeiserverWeb, :live_view
  alias Teiserver.{Account, Battle, Game}
  alias Teiserver.Game.MatchRatingLib

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

  # defp apply_action(socket, :edit, %{"id" => id}) do
  #   socket
  #   |> assign(:page_title, "Edit Category")
  #   |> assign(:category, Board.get_category!(id))
  # end

  # defp apply_action(socket, :new, _params) do
  #   socket
  #   |> assign(:page_title, "New Category")
  #   |> assign(:category, %Category{})
  # end

  # defp apply_action(socket, :index, _params) do
  #   socket
  #   |> assign(:page_title, "Listing Categories")
  #   |> assign(:category, nil)
  # end

  # @impl true
  # def handle_info({TeiserverWeb.CategoryLive.FormComponent, {:saved, category}}, socket) do
  #   {:noreply, stream_insert(socket, :categories, category)}
  # end

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
      changes = run_match_query(filters, rating_type, current_user)

      if changes != nil do
        socket
        |> assign(:logs, changes.logs)
        |> assign(:stats, changes.stats)
      else
        socket
      end
    else
      socket
      |> assign(:logs, [])
      |> assign(:stats, %{
        games: [],
        winrate: 0,
        first_log: nil
      })
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

    games = Enum.count(logs) |> max(1)
    wins = Enum.count(logs, fn l -> l.match_membership.win end)

    first_log =
      case Enum.reverse(logs) do
        [l | _] -> l
        _ -> nil
      end

    stats = %{
      games: games,
      winrate: wins / games,
      first_log: first_log
    }

    %{
      logs: logs,
      stats: stats
    }
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
