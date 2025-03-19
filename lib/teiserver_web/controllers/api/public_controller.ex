defmodule TeiserverWeb.API.PublicController do
  use TeiserverWeb, :controller
  alias Teiserver.Account

  @rating_types [
    "Small Team",
    "Large Team",
    "Duel",
    "FFA"
  ]

  @spec leaderboard(Plug.Conn.t(), map) :: Plug.Conn.t()
  def leaderboard(conn, %{"season" => season_param}) do
    activity_time =
      Timex.today()
      |> Timex.shift(days: -350)
      |> Timex.to_datetime()

    case Integer.parse(season_param) do
      {season, ""} ->
        rating_type_lookup = Teiserver.Game.MatchRatingLib.rating_type_name_lookup()

        ratings =
          @rating_types
          |> Enum.map(fn rating_type ->
            {rating_type, rating_type_lookup[rating_type]}
          end)
          |> Enum.filter(fn {_, type_id} -> not is_nil(type_id) end)
          |> Enum.map(fn {rating_type, type_id} ->
            players =
              Account.list_ratings(
                search: [
                  updated_after: activity_time,
                  season: season,
                  rating_type_id: type_id
                ],
                order_by: "Leaderboard rating high to low",
                preload: [:user],
                limit: 100
              )
              |> Enum.sort_by(&(-&1.leaderboard_rating))
              |> Enum.take(100)
              |> Enum.map(fn r ->
                %{
                  id: r.user_id,
                  name: r.user.name,
                  rating: r.leaderboard_rating
                }
              end)

            %{
              name: rating_type,
              players: players
            }
          end)

        conn
        |> put_status(200)
        |> json(ratings)

      _ ->
        conn
        |> put_status(400)
        |> json(%{error: "Invalid season parameter"})
    end
  end

  @spec leaderboard(Plug.Conn.t(), map) :: Plug.Conn.t()
  def leaderboard(conn, _params) do
    active_season = Teiserver.Config.get_site_config_cache("rating.Season")

    # For every active season from 1 to active_season create a map containing season and game type
    seasons =
      Enum.map(1..active_season, fn season ->
        %{
          season: season,
          game_types: @rating_types
        }
      end)

    conn
    |> put_status(200)
    |> json(seasons)
  end
end
