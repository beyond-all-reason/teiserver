defmodule TeiserverWeb.Battle.MatchLive.Ratings do
  use TeiserverWeb, :live_view
  alias Teiserver.{Account, Battle, Game}
  alias Teiserver.Game.MatchRatingLib
  import TeiserverWeb.PaginationComponents, only: [pagination: 1]

  @impl true
  def mount(params, _ession, socket) do
    game_types = Battle.MatchLib.list_rated_game_types()

    user_ratings =
      Account.list_ratings(
        search: [
          user_id: socket.assigns.current_user.id,
          season: MatchRatingLib.active_season()
        ],
        preload: [:rating_type]
      )
      |> Map.new(fn rating ->
        {rating.rating_type.name, rating}
      end)

    socket =
      socket
      |> assign(:site_menu_active, "match")
      |> assign(:view_colour, Battle.MatchLib.colours())
      |> assign(:game_types, game_types)
      |> assign(:user_ratings, user_ratings)
      |> assign(:rating_type, Map.get(params, "rating_type", "Large Team"))
      |> assign(:rating_type_list, MatchRatingLib.rating_type_list())
      |> assign(:rating_type_id_lookup, MatchRatingLib.rating_type_id_lookup())
      |> add_breadcrumb(name: "Matches", url: "/battle")
      |> add_breadcrumb(name: "Ratings", url: "/battle/ratings")
      |> default_filters()
      |> default_pagination()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    parsed = TeiserverWeb.Parsers.PaginationParams.parse_params(params)

    # Decode the rating_type if it comes from URL params (to handle %20 vs +)
    rating_type =
      case Map.get(params, "rating_type") do
        nil -> "Large Team"
        encoded -> URI.decode_www_form(encoded)
      end

    socket =
      socket
      |> assign(:rating_type, rating_type)
      |> assign(:page, parsed.page - 1)
      |> assign(:limit, parsed.limit)
      |> update_match_list()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter-update", event, %{assigns: %{filters: filters}} = socket) do
    [key] = event["_target"]
    value = event[key]

    new_filters = Map.put(filters, key, value)

    socket =
      socket
      |> assign(:filters, new_filters)
      |> assign(:page, 0)
      |> update_match_list()

    {:noreply, socket}
  end

  defp update_match_list(
         %{
           assigns: %{
             rating_type: rating_type,
             filters: filters,
             current_user: current_user,
             page: page,
             limit: limit
           }
         } =
           socket
       ) do
    if connected?(socket) do
      changes = run_match_query(filters, rating_type, current_user, page, limit)

      total_pages = div(changes.total_count - 1, limit) + 1

      socket
      |> assign(:logs, changes.logs)
      |> assign(:stats, changes.stats)
      |> assign(:total_count, changes.total_count)
      |> assign(:total_pages, total_pages)
      |> assign(:current_count, Enum.count(changes.logs))
    else
      socket
      |> assign(:logs, [])
      |> assign(:stats, %{
        games: [],
        winrate: 0,
        first_log: nil
      })
      |> assign(:total_count, 0)
      |> assign(:total_pages, 0)
      |> assign(:current_count, 0)
    end
  end

  defp update_match_list(socket) do
    socket
  end

  defp run_match_query(_filters, rating_type, user, page, limit) do
    filter_type_id = MatchRatingLib.rating_type_name_lookup()[rating_type] || 1

    search_params = [
      user_id: user.id,
      rating_type_id: filter_type_id,
      season: MatchRatingLib.active_season()
    ]

    total_count = Game.count_rating_logs(search: search_params)

    logs =
      Game.list_rating_logs(
        search: search_params,
        order_by: "Newest first",
        limit: limit,
        offset: page * limit,
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
      stats: stats,
      total_count: total_count
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

  defp default_pagination(socket) do
    socket
    |> assign(:page, 0)
    |> assign(:limit, 100)
    |> assign(:total_count, 0)
    |> assign(:total_pages, 0)
    |> assign(:current_count, 0)
  end
end
