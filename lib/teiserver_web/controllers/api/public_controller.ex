defmodule TeiserverWeb.API.PublicController do
  use TeiserverWeb, :controller
  alias Teiserver.Game.MatchRatingLib
  alias Teiserver.Account

  @spec leaderboard(Plug.Conn.t(), map) :: Plug.Conn.t()
  def leaderboard(conn, %{"type" => type_name}) do
    type_id = MatchRatingLib.rating_type_name_lookup()[type_name]

    activity_time =
      Timex.today()
      |> Timex.shift(days: -35)
      |> Timex.to_datetime()

    ratings =
      case type_id do
        nil ->
          %{"result" => "error", "reason" => "Invalid type"}

        _ ->
          Account.list_ratings(
            search: [
              rating_type_id: type_id,
              updated_after: activity_time
            ],
            order_by: "Leaderboard rating high to low",
            preload: [:user],
            limit: 100
          )
          |> Enum.map(fn rating ->
            %{
              name: rating.user.name,
              icon: rating.user.icon,
              country: Map.get(rating.user.data, "country", "??"),
              colour: rating.user.colour,
              rating: rating.leaderboard_rating,
              age: Timex.diff(Timex.now(), rating.last_updated, :days)
            }
          end)
      end

    conn
    |> put_status(201)
    |> assign(:result, %{ratings: ratings})
    |> render("result.json")
  end
end
