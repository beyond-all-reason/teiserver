defmodule TeiserverWeb.Admin.MatchController do
  use CentralWeb, :controller

  alias Teiserver.{Battle, Game}
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

    conn
    |> assign(:match, match)
    |> assign(:match_name, match_name)
    |> assign(:members, members)
    |> add_breadcrumb(name: "Show: #{match_name}", url: conn.request_path)
    |> render("show.html")
  end
end
