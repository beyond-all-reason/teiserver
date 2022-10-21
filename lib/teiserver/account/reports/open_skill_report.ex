defmodule Teiserver.Account.OpenSkillReport do
  require Logger

  alias Teiserver.Game.MatchRatingLib
  alias Central.Repo

  @spec icon() :: String.t()
  def icon(), do: "fa-regular fa-chart-line"

  @spec permissions() :: String.t()
  def permissions(), do: "teiserver.admin"

  @spec run(Plug.Conn.t(), map()) :: {list(), map()}
  def run(_conn, params) do
    params = apply_defaults(params)

    rating_type_id = MatchRatingLib.rating_type_name_lookup()[params["rating_type"]]
    metrics_column_name = convert_metrics_name_to_db_column_name(params["metrics"])

    data = query_data(metrics_column_name, rating_type_id)

    assigns = %{
      params: params
    }

    {data, assigns}
  end

  defp query_data(metrics_column_name, rating_type_id) do
    query = """
    SELECT ROUND(#{metrics_column_name}) #{metrics_column_name}_rounded, COUNT(user_id) #{metrics_column_name}
    FROM
      teiserver_account_ratings
    WHERE
      rating_type_id = #{rating_type_id}
    GROUP BY
    #{metrics_column_name}_rounded
    ORDER BY
    #{metrics_column_name}_rounded
    """

    case Ecto.Adapters.SQL.query(Repo, query, []) do
      {:ok, results} ->
        [results.columns | results.rows]

      {a, b} ->
        raise "ERR: #{a}, #{b}"
    end
  end

  defp apply_defaults(params) do
    Map.merge(
      %{
        "rating_type" => "Team",
        "metrics" => "Rating"
      },
      Map.get(params, "report", %{})
    )
  end

  defp convert_metrics_name_to_db_column_name("Rating"), do: "rating_value"
  defp convert_metrics_name_to_db_column_name("Skill"), do: "skill"
  defp convert_metrics_name_to_db_column_name("Uncertainty"), do: "uncertainty"
  defp convert_metrics_name_to_db_column_name("Leaderboard Rating"), do: "leaderboard_rating"
  defp convert_metrics_name_to_db_column_name(unhandled_rating_metrics), do: Logger.error("use of unhandled rating metrics: #{unhandled_rating_metrics}")
end
