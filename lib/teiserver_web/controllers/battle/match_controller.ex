defmodule TeiserverWeb.Battle.MatchController do
  use TeiserverWeb, :controller

  alias Teiserver.{Battle, Game, Account}
  alias Teiserver.Game.MatchRatingLib
  alias Teiserver.Battle.MatchLib
  alias Teiserver.Helper.TimexHelper

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Battle.Match,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}

  plug(AssignPlug,
    site_menu_active: "match",
    sub_menu_active: "match"
  )

  plug :add_breadcrumb, name: "Matches", url: "/battle"

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    matches =
      Battle.list_matches(
        search: [
          user_id: conn.assigns.current_user.id
        ],
        preload: [
          :queue
        ],
        order_by: "Newest first",
        limit: 50
      )

    conn
    |> assign(:matches, matches)
    |> render("index.html")
  end

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    match =
      Battle.get_match!(id,
        preload: [:members_and_users]
      )

    match
    |> MatchLib.make_favourite()
    |> insert_recently(conn)

    match_name = MatchLib.make_match_name(match)

    members =
      match.members
      |> Enum.sort_by(fn m -> m.user.name end, &<=/2)
      |> Enum.sort_by(fn m -> m.team_id end, &<=/2)

    rating_logs =
      Game.list_rating_logs(
        search: [
          match_id: match.id
        ]
      )
      |> Map.new(fn log -> {log.user_id, log} end)

    # Creates a map where the party_id refers to an integer
    # but only includes parties with 2 or more members
    parties =
      members
      |> Enum.group_by(fn m -> m.party_id end)
      |> Map.drop([nil])
      |> Map.filter(fn {_id, members} -> Enum.count(members) > 1 end)
      |> Map.keys()
      |> Enum.zip(Teiserver.Helper.StylingHelper.bright_hex_colour_list())
      |> Map.new()

    conn
    |> assign(:match, match)
    |> assign(:match_name, match_name)
    |> assign(:members, members)
    |> assign(:rating_logs, rating_logs)
    |> assign(:parties, parties)
    |> add_breadcrumb(name: "Show: #{match_name}", url: conn.request_path)
    |> render("show.html")
  end

  @spec ratings(Plug.Conn.t(), map) :: Plug.Conn.t()
  def ratings(conn, params) do
    user = conn.assigns.current_user

    filter = params["filter"] || "Large Team"
    filter_type_id = MatchRatingLib.rating_type_name_lookup()[filter] || 1
    season = MatchRatingLib.active_season()

    page = (params["page"] || "1") |> String.to_integer() |> max(1) |> then(&(&1 - 1))
    limit = (params["limit"] || "50") |> String.to_integer() |> max(1)

    ratings =
      Account.list_ratings(
        search: [
          user_id: user.id,
          season: season
        ],
        preload: [:rating_type]
      )
      |> Map.new(fn rating ->
        {rating.rating_type.name, rating}
      end)

    total_count =
      Game.count_rating_logs(
        search: [
          user_id: user.id,
          rating_type_id: filter_type_id,
          season: season
        ]
      )

    logs =
      Game.list_rating_logs(
        search: [
          user_id: user.id,
          rating_type_id: filter_type_id,
          season: season
        ],
        order_by: "Newest first",
        limit: limit,
        offset: page * limit,
        preload: [:match, :match_membership]
      )

    total_pages = max(1, div(total_count - 1, limit) + 1)
    current_count = Enum.count(logs)

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

    conn
    |> assign(:filter, filter || "rating-all")
    |> assign(:user, user)
    |> assign(:ratings, ratings)
    |> assign(:logs, logs)
    |> assign(:rating_type_list, MatchRatingLib.rating_type_list())
    |> assign(:rating_type_id_lookup, MatchRatingLib.rating_type_id_lookup())
    |> assign(:stats, stats)
    |> assign(:page, page)
    |> assign(:limit, limit)
    |> assign(:total_pages, total_pages)
    |> assign(:total_count, total_count)
    |> assign(:current_count, current_count)
    |> assign(:params, params)
    |> add_breadcrumb(name: "Ratings: #{user.name}", url: conn.request_path)
    |> render("ratings.html")
  end

  @spec ratings_graph(Plug.Conn.t(), map) :: Plug.Conn.t()
  def ratings_graph(conn, params) do
    user = conn.assigns.current_user

    filter = params["filter"] || "Large Team"
    filter_type_id = MatchRatingLib.rating_type_name_lookup()[filter] || 1
    season = MatchRatingLib.active_season()

    ratings =
      Account.list_ratings(
        search: [
          user_id: user.id,
          season: season
        ],
        preload: [:rating_type]
      )
      |> Map.new(fn rating ->
        {rating.rating_type.name, rating}
      end)

    logs =
      Game.list_rating_logs(
        search: [
          user_id: user.id,
          rating_type_id: filter_type_id,
          season: season
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

    conn
    |> assign(:filter, filter || "rating-all")
    |> assign(:rating_type_list, MatchRatingLib.rating_type_list())
    |> assign(:ratings, ratings)
    |> assign(:data, data)
    |> add_breadcrumb(name: "Progression", url: "/battle/progression")
    |> render("ratings_graph.html")
  end
end
