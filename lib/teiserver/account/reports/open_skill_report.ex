defmodule Teiserver.Account.OpenSkillReport do
  require Logger

  alias Teiserver.Game.MatchRatingLib
  alias Teiserver.Repo
  import Teiserver.Helper.NumberHelper, only: [int_parse: 1]

  @spec icon() :: String.t()
  def icon(), do: "fa-solid fa-chart-line"

  @spec permissions() :: String.t()
  def permissions(), do: "Admin"

  @spec run(Plug.Conn.t(), map()) :: {nil, map()}
  def run(_conn, params) do
    params = apply_defaults(params)

    last_active =
      case params["last_active"] do
        "Forever" -> Timex.today() |> Timex.shift(years: -1000) |> Timex.to_datetime()
        "7 days" -> Timex.today() |> Timex.shift(days: -7) |> Timex.to_datetime()
        "31 days" -> Timex.today() |> Timex.shift(days: -31) |> Timex.to_datetime()
        "180 days" -> Timex.today() |> Timex.shift(days: -180) |> Timex.to_datetime()
      end

    uncertainty = params["uncertainty"] |> int_parse

    rating_type_id = MatchRatingLib.rating_type_name_lookup()[params["rating_type"]]
    metric_column_name = convert_metric_name_to_db_column_name(params["metric"])

    data = query_data(metric_column_name, rating_type_id, last_active, uncertainty)

    assigns = %{
      params: params,
      results: data
    }

    {nil, assigns}
  end

  defp query_data(metric_column_name, rating_type_id, last_active, uncertainty) do
    query = """
    SELECT
      ROUND(#{metric_column_name}) #{metric_column_name}_rounded,
      COUNT(user_id) #{metric_column_name}
    FROM
      teiserver_account_ratings
    WHERE
      rating_type_id = $1
    AND
      last_updated >= $2
    AND
      uncertainty <= $3
    GROUP BY
      #{metric_column_name}_rounded
    ORDER BY
      #{metric_column_name}_rounded
    """

    case Ecto.Adapters.SQL.query(Repo, query, [rating_type_id, last_active, uncertainty]) do
      {:ok, results} ->
        [results.columns | results.rows]

      {a, b} ->
        raise "ERR: #{a}, #{b}"
    end
  end

  defp apply_defaults(params) do
    Map.merge(
      %{
        "rating_type" => "Large Team",
        "metric" => "Game Rating",
        "last_active" => "7 days",
        "uncertainty" => "5"
      },
      Map.get(params, "report", %{})
    )
  end

  defp convert_metric_name_to_db_column_name("Game Rating"), do: "rating_value"
  defp convert_metric_name_to_db_column_name("Skill"), do: "skill"
  defp convert_metric_name_to_db_column_name("Uncertainty"), do: "uncertainty"
  defp convert_metric_name_to_db_column_name("Leaderboard Rating"), do: "leaderboard_rating"

  defp convert_metric_name_to_db_column_name(unhandled_rating_metric),
    do: Logger.error("use of unhandled rating metric: #{unhandled_rating_metric}")
end
