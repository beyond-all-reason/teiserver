defmodule TeiserverWeb.Battle.RatingsController do
  use TeiserverWeb, :controller

  alias Teiserver.{Account}
  alias Teiserver.Game.MatchRatingLib

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Battle.Match,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}

  plug(AssignPlug,
    site_menu_active: "leaderboard",
    sub_menu_active: "match"
  )

  plug :add_breadcrumb, name: "Matches", url: "/teiserver/matches"

  @spec leaderboard(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def leaderboard(conn, params) do
    activity_time =
      Timex.today()
      |> Timex.shift(days: -35)
      |> Timex.to_datetime()

    type_name = params["type"]

    {type_id, type_name} =
      case MatchRatingLib.rating_type_name_lookup()[type_name] do
        nil ->
          type_name = hd(MatchRatingLib.rating_type_list())
          {MatchRatingLib.rating_type_name_lookup()[type_name], type_name}

        v ->
          {v, type_name}
      end

    my_rating = Account.get_rating(conn.assigns.current_user.id, type_id)

    ratings =
      Account.list_ratings(
        search: [
          rating_type_id: type_id,
          updated_after: activity_time,
          season: MatchRatingLib.active_season()
        ],
        order_by: "Leaderboard rating high to low",
        preload: [:user],
        limit: 100
      )

    conn
    |> add_breadcrumb(name: "Leaderboard", url: conn.request_path)
    |> assign(:type_name, type_name)
    |> assign(:type_id, type_id)
    |> assign(:ratings, ratings)
    |> assign(:my_rating, my_rating)
    |> render("leaderboard.html")
  end
end
