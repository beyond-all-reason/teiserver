defmodule TeiserverWeb.Admin.MatchController do
  use CentralWeb, :controller

  alias Teiserver.{Battle, Game, Account}
  alias Teiserver.Battle.MatchLib

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Moderator,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug(AssignPlug,
    site_menu_active: "teiserver_user",
    sub_menu_active: "match"
  )

  plug :add_breadcrumb, name: 'Teiserver', url: '/teiserver'
  plug :add_breadcrumb, name: 'Admin', url: '/teiserver/admin'
  plug :add_breadcrumb, name: 'Matches', url: '/teiserver/admin/matches'

  @spec index(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def index(conn, params) do
    matches = Battle.list_matches(
        search: [

        ],
        preload: [
          :queue
        ],
        order_by: "Newest first"
      )

    queues = Game.list_queues(order_by: "Name (A-Z)")

    conn
      |> assign(:queues, queues)
      |> assign(:params, params)
      |> assign(:matches, matches)
      |> render("index.html")
  end

  @spec search(Plug.Conn.t(), map) :: Plug.Conn.t()
  def search(conn, %{"search" => params}) do
    matches = Battle.list_matches(
      search: [
        user_id: Map.get(params, "account_user", "") |> get_hash_id,
        queue_id: params["queue"],
        game_type: params["game_type"],
      ],
      preload: [
        :queue
      ],
      order_by: "Newest first"
    )

    queues = Game.list_queues(order_by: "Name (A-Z)")

    conn
      |> assign(:queues, queues)
      |> assign(:params, params)
      |> assign(:matches, matches)
      |> render("index.html")
  end

  @spec show(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    match = Battle.get_match!(id, [
      joins: [],
      preload: [:members_and_users]
    ])

    members = match.members
      |> Enum.sort_by(fn m -> m.user.name end, &<=/2)
      |> Enum.sort_by(fn m -> m.team_id end, &<=/2)

    match
      |> MatchLib.make_favourite
      |> insert_recently(conn)

    match_name = MatchLib.make_match_name(match)

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

  @spec user_show(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def user_show(conn, %{"user_id" => userid}) do
    matches = Battle.list_matches(
      search: [
        user_id: userid
      ],
      preload: [
        :queue
      ],
      order_by: "Newest first",
      limit: 100
    )

    queues = Game.list_queues(order_by: "Name (A-Z)")
    user = Account.get_user_by_id(userid)

    conn
      |> assign(:user, user)
      |> assign(:queues, queues)
      |> assign(:matches, matches)
      |> render("user_index.html")
  end

  @spec server_index(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def server_index(conn, %{"uuid" => uuid}) do
    matches = Battle.list_matches(
        search: [
          server_uuid: uuid
        ],
        order_by: "Newest first"
      )

    conn
      |> assign(:uuid, uuid)
      |> assign(:matches, matches)
      |> render("server_index.html")
  end
end
