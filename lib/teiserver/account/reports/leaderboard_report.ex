defmodule Teiserver.Account.LeaderboardReport do
  # alias Central.Helpers.{DatePresets, TimexHelper}
  alias Teiserver.Account
  alias Teiserver.Game.MatchRatingLib
  # alias Teiserver.Battle.BalanceLib
  import Central.Helpers.NumberHelper, only: [int_parse: 1]

  @spec icon() :: String.t()
  def icon(), do: Teiserver.Account.RatingLib.icon()

  @spec permissions() :: String.t()
  def permissions(), do: "teiserver.admin"

  @spec run(Plug.Conn.t(), map()) :: {list(), map()}
  def run(_conn, params) do
    params = apply_defaults(params)

    days = params["days"] |> int_parse
    limit = params["limit"] |> int_parse

    activity_time = Timex.today()
      |> Timex.shift(days: -days)
      |> Timex.to_datetime()

    type_name = params["game_type"]
    {type_id, _type_name} = case MatchRatingLib.rating_type_name_lookup()[type_name] do
      nil ->
        type_name = hd(MatchRatingLib.rating_type_list())
        {MatchRatingLib.rating_type_name_lookup()[type_name], type_name}
      v ->
        {v, type_name}
    end

    ratings = Account.list_ratings(
      search: [
        rating_type_id: type_id,
        updated_after: activity_time
      ],
      order_by: "Leaderboard rating high to low",
      preload: [:user],
      limit: limit
    )

    data = %{
      ratings: ratings,
      csv_data: make_csv_data(ratings)
    }

    assigns = %{
      params: params,
      game_types: MatchRatingLib.rating_type_list()
      # presets: DatePresets.presets()
    }

    {data, assigns}
  end

  defp add_csv_headings(output) do
    headings = [[
      "Pos",
      "Player",
      "Leaderboard rating",
      "Game rating",
      "Skill",
      "Uncertainty",
      "Days since update"
    ]]
    headings ++ output
  end
  defp make_csv_data(ratings) do
    ratings
      |> Enum.with_index()
      |> Enum.map(fn {rating, index} ->
        age = Timex.diff(Timex.now(), rating.last_updated, :days)

        [
          index + 1,
          rating.user.name,
          rating.leaderboard_rating,
          rating.rating_value,
          rating.skill,
          rating.uncertainty,
          age
        ]
      end)
      |> add_csv_headings
      |> CSV.encode(separator: ?\t)
      |> Enum.to_list
  end

  defp apply_defaults(params) do
    Map.merge(%{
      "days" => "35",
      "limit" => "50",
      "game_type" => (MatchRatingLib.rating_type_list() |> hd)
    }, Map.get(params, "report", %{}))
  end
end
