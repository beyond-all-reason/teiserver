defmodule TeiserverWeb.Battle.RatingsController do
  use CentralWeb, :controller

  alias Teiserver.{Battle, Game, Account}
  alias Teiserver.Game.MatchRatingLib
  alias Teiserver.Battle.MatchLib

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Battle.Match,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug(AssignPlug,
    site_menu_active: "teiserver_match",
    sub_menu_active: "match"
  )

  plug :add_breadcrumb, name: 'Battle', url: '/teiserver'
  plug :add_breadcrumb, name: 'Logs', url: '/teiserver/matches'

  @spec leaderboard(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def leaderboard(conn, params) do
    type_name = params["type"]
    {type_id, type_name} = case MatchRatingLib.rating_type_name_lookup()[type_name] do
      nil ->
        type_name = hd(MatchRatingLib.rating_type_list())
        {MatchRatingLib.rating_type_name_lookup()[type_name], type_name}
      v ->
        {v, type_name}
    end

    ratings = Account.list_ratings(
      search: [
        rating_type_id: type_id
      ],
      order_by: "Ordinal high to low",
      preload: [:user],
      limit: 100
    )

    conn
      |> assign(:type_name, type_name)
      |> assign(:type_id, type_id)
      |> assign(:ratings, ratings)
      |> render("leaderboard.html")
  end

end
