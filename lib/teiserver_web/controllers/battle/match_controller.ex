defmodule TeiserverWeb.Battle.MatchController do
  use CentralWeb, :controller

  alias Teiserver.{Battle, Game, Account}
  alias Teiserver.Game.MatchRatingLib
  alias Teiserver.Battle.MatchLib

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Battle.Match,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug(AssignPlug,
    site_menu_active: "match",
    sub_menu_active: "match"
  )

  plug :add_breadcrumb, name: 'Matches', url: '/teiserver/matches'

  @spec index(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def index(conn, _params) do
    matches = Battle.list_matches(
      search: [
        user_id: conn.user_id
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

  @spec show(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    match = Battle.get_match!(id, [
      preload: [:members_and_users],
    ])

    match
    |> MatchLib.make_favourite
    |> insert_recently(conn)

    match_name = MatchLib.make_match_name(match)

    members = match.members
      |> Enum.sort_by(fn m -> m.user.name end, &<=/2)
      |> Enum.sort_by(fn m -> m.team_id end, &<=/2)

    rating_logs = Game.list_rating_logs(
      search: [
        match_id: match.id
      ]
    )
    |> Map.new(fn log -> {log.user_id, log} end)

    # Creates a map where the party_id refers to an integer
    # but only includes parties with 2 or more members
    parties = members
      |> Enum.group_by(fn m -> m.party_id end)
      |> Map.drop([nil])
      |> Map.filter(fn {_id, members} -> Enum.count(members) > 1 end)
      |> Map.keys()
      |> Enum.zip(Central.Helpers.StylingHelper.bright_hex_colour_list)
      |> Map.new

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

    filter = params["filter"] || "Team"
    filter_type_id = MatchRatingLib.rating_type_name_lookup()[filter] || 1

    ratings = Account.list_ratings(
      search: [
        user_id: user.id
      ],
      preload: [:rating_type]
    )
      |> Map.new(fn rating ->
        {rating.rating_type.name, rating}
      end)

    logs = Game.list_rating_logs(
      search: [
        user_id: user.id,
        rating_type_id: filter_type_id
      ],
      order_by: "Newest first",
      limit: 50,
      preload: [:match, :match_membership]
    )

    games = Enum.count(logs) |> max(1)
    wins = Enum.filter(logs, fn l -> l.match_membership.win end) |> Enum.count

    stats = %{
      games: games,
      winrate: wins/games,

      first_log: logs |> Enum.reverse |> hd,
    }

    conn
      |> assign(:filter, filter || "rating-all")
      |> assign(:user, user)
      |> assign(:ratings, ratings)
      |> assign(:logs, logs)
      |> assign(:rating_type_list, MatchRatingLib.rating_type_list())
      |> assign(:rating_type_id_lookup, MatchRatingLib.rating_type_id_lookup())
      |> assign(:stats, stats)
      |> add_breadcrumb(name: "Ratings: #{user.name}", url: conn.request_path)
      |> render("ratings.html")

  end
end
