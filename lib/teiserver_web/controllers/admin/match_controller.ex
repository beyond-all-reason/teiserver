defmodule TeiserverWeb.Admin.MatchController do
  use CentralWeb, :controller

  alias Teiserver.Battle
  alias Teiserver.Battle.MatchLib

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Moderator,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug AssignPlug,
    sidemenu_active: ["teiserver"]

  plug :add_breadcrumb, name: 'Teiserver', url: '/teiserver'
  plug :add_breadcrumb, name: 'Admin', url: '/teiserver/admin'
  plug :add_breadcrumb, name: 'Matches', url: '/teiserver/admin/matches'

  @spec index(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def index(conn, params) do
    matches = Battle.list_matches(
        search: [
          simple_search: Map.get(params, "s", "") |> String.trim(),
          filter: params["filter"] || "all"
        ],
        preload: [
          :giver,
          :recipient,
          :badge_type
        ],
        order_by: "Newest first"
      )

    conn
    |> assign(:matches, matches)
    |> render("index.html")
  end

  @spec user_show(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def user_show(conn, %{"user_id" => user_id}) do
    # match_ids = Battle.list_match_memberships(search: [user_id: user_id])
    # |> Enum.map(fn mm -> mm.match_id end)

    # IO.puts ""
    # IO.inspect match_ids
    # IO.puts ""

    matches =
      Battle.list_matches(
        search: [
          # id_list: match_ids,
          user_id: user_id,
          processed: :true,
        ],
        preload: [
          # :members_and_users
        ],
        order_by: "Newest first"
      )

    conn
    |> assign(:matches, matches)
    |> render("user_index.html")
  end

  @spec show(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    match = Battle.get_match!(id, [
      joins: [],
      preload: [:members_and_users]
    ])

    match
    |> MatchLib.make_favourite
    |> insert_recently(conn)

    match_name = MatchLib.make_match_name(match)

    conn
    |> assign(:match, match)
    |> assign(:match_name, match_name)
    |> add_breadcrumb(name: "Show: #{match_name}", url: conn.request_path)
    |> render("show.html")
  end
end
