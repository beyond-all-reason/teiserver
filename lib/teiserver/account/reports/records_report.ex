defmodule Teiserver.Account.RecordsReport do
  alias Central.Repo
  alias Teiserver.Telemetry

  @spec icon() :: String.t()
  def icon(), do: "fa-solid fa-trophy"

  @spec permissions() :: String.t()
  def permissions(), do: "Admin"

  @top_count 3

  @spec run(Plug.Conn.t(), map()) :: {nil, map()}
  def run(_conn, _params) do
    records = [
      {"Peak users", get_top(~w(aggregates stats peak_user_counts total))},
      {"Peak players", get_top(~w(aggregates stats peak_user_counts player))},
      {"Unique users", get_top(~w(aggregates stats unique_users))},
      {"Unique players", get_top(~w(aggregates stats unique_players))},
      {"Total time (days)", get_top(~w(aggregates minutes total)) |> minutes_to_days},
      {"Player time (days)", get_top(~w(aggregates minutes player)) |> minutes_to_days}
    ]

    # force_recache = (Map.get(params, "recache", false) == "true")
    force_recache = false
    today = Telemetry.get_todays_server_log(force_recache)

    today_data = %{
      "Peak users" => today["aggregates"]["stats"]["peak_user_counts"]["total"],
      "Peak players" => today["aggregates"]["stats"]["peak_user_counts"]["player"],
      "Unique users" => today["aggregates"]["stats"]["unique_users"],
      "Unique players" => today["aggregates"]["stats"]["unique_players"],
      "Total time (days)" => today["aggregates"]["minutes"]["total"] |> Kernel.div(1440) |> round,
      "Player time (days)" =>
        today["aggregates"]["minutes"]["player"] |> Kernel.div(1440) |> round
    }

    %{
      top_count: @top_count,
      records: records,
      today: today_data
    }
  end

  defp get_top(fields) do
    path =
      fields
      |> Enum.map_join(" -> ", fn f -> "'#{f}'" end)

    query = """
      SELECT
        logs.date,
        logs.data -> #{path}
      FROM teiserver_server_day_logs logs
      ORDER BY
        (logs.data -> #{path}) DESC
      LIMIT $1
    """

    case Ecto.Adapters.SQL.query(Repo, query, [@top_count]) do
      {:ok, results} ->
        results.rows

      {a, b} ->
        raise "ERR: #{a}, #{b}"
    end
  end

  defp minutes_to_days_cell([key, minutes]) do
    [key, round(minutes / 1440)]
  end

  defp minutes_to_days(rows) do
    rows
    |> Enum.map(fn row ->
      minutes_to_days_cell(row)
    end)
  end
end
