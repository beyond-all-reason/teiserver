defmodule Teiserver.Account.LeaderboardReport do
  alias Teiserver.{Account}
  alias Teiserver.Game.MatchRatingLib
  # alias Teiserver.Battle.BalanceLib
  import Teiserver.Helper.NumberHelper, only: [int_parse: 1]
  alias Teiserver.Repo

  @spec icon() :: String.t()
  def icon(), do: Teiserver.Account.RatingLib.icon()

  @spec permissions() :: String.t()
  def permissions(), do: "Admin"

  @spec run(Plug.Conn.t(), map()) :: {nil, map()}
  def run(_conn, params) do
    params = apply_defaults(params)

    days = params["days"] |> int_parse()
    limit = params["limit"] |> int_parse()

    activity_time =
      Timex.today()
      |> Timex.shift(days: -days)
      |> Timex.to_datetime()

    type_name = params["game_type"]

    {type_id, type_name} =
      case MatchRatingLib.rating_type_name_lookup()[type_name] do
        nil ->
          type_name = hd(MatchRatingLib.rating_type_list())
          {MatchRatingLib.rating_type_name_lookup()[type_name], type_name}

        v ->
          {v, type_name}
      end

    ratings =
      Account.list_ratings(
        search: [
          rating_type_id: type_id,
          updated_after: activity_time,
          season: MatchRatingLib.active_season()
        ],
        order_by: "Leaderboard rating high to low",
        preload: [:user],
        limit: limit
      )

    extra_data =
      if params["extended"] == "true" do
        userids = ratings |> Enum.map(fn r -> r.user_id end)

        get_extra_data(userids, activity_time, type_name)
      else
        nil
      end

    assigns = %{
      params: params,
      game_types: MatchRatingLib.rating_type_list(),
      ratings: ratings,
      extra_data: extra_data,
      csv_data: make_csv_data(ratings, extra_data)
    }

    {nil, assigns}
  end

  defp add_csv_headings(output) do
    headings = [
      [
        "Pos",
        "Player",
        "Leaderboard rating",
        "Game rating",
        "Skill",
        "Uncertainty",
        "Days since update",
        "Game count",
        "Win rate",
        "Stayed %",
        "Early %",
        "Abandoned %",
        "Noshow %"
      ]
    ]

    headings ++ output
  end

  defp make_csv_data(ratings, extra_data) do
    ratings
    |> Enum.with_index()
    |> Enum.map(fn {rating, index} ->
      age = Timex.diff(Timex.now(), rating.last_updated, :days)

      extra =
        extra_data[rating.user_id] ||
          %{
            count: 1,
            wins: 1,
            stayed: 0,
            early: 0,
            abandoned: 0,
            noshow: 0
          }

      [
        index + 1,
        rating.user.name,
        rating.leaderboard_rating,
        rating.rating_value,
        rating.skill,
        rating.uncertainty,
        age,
        extra.count,
        extra.wins / extra.count,
        extra.stayed,
        extra.early,
        extra.abandoned,
        extra.noshow
      ]
    end)
    |> add_csv_headings()
    |> CSV.encode(separator: ?\t)
    |> Enum.to_list()
  end

  defp apply_defaults(params) do
    Map.merge(
      %{
        "days" => "35",
        "limit" => "50",
        "game_type" => MatchRatingLib.rating_type_list() |> hd(),
        "extended" => "false"
      },
      Map.get(params, "report", %{})
    )
  end

  defp get_extra_data(userids, after_date, type_name) do
    query = """
      SELECT
        memberships.user_id,
        COUNT(memberships.user_id) AS count,
        SUM(cast(memberships.win as int)) AS wins
      FROM
        teiserver_battle_match_memberships memberships
      JOIN teiserver_battle_matches matches
        ON matches.id = memberships.match_id
      JOIN teiserver_game_rating_logs rating_logs
        ON matches.id = rating_logs.match_id AND rating_logs.user_id = memberships.user_id
      WHERE
        memberships.user_id = ANY($1)
        AND matches.started > $2
        AND matches.game_type = $3
      GROUP BY
        memberships.user_id
    """

    case Ecto.Adapters.SQL.query(Repo, query, [userids, after_date, type_name]) do
      {:ok, results} ->
        results.rows
        |> Map.new(fn [userid, count, wins] ->
          stats = Account.get_user_stat_data(userid)

          {userid,
           %{
             stayed: stats["exit_status.team.stayed"],
             early: stats["exit_status.team.early"],
             abandoned: stats["exit_status.team.abandoned"],
             noshow: stats["exit_status.team.noshow"],
             count: count,
             wins: wins
           }}
        end)

      {a, b} ->
        raise "ERR: #{a}, #{b}"
    end
  end
end
