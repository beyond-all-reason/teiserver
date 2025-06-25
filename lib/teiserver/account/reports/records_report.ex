defmodule Teiserver.Account.RecordsReport do
  @moduledoc false
  alias Teiserver.Repo
  alias Teiserver.Logging
  alias Teiserver.Helper.DatePresets

  @spec icon() :: String.t()
  def icon(), do: "fa-solid fa-trophy"

  @spec permissions() :: String.t()
  def permissions(), do: "Admin"

  @top_count 3

  @spec run(Plug.Conn.t(), map()) :: {nil, map()}
  def run(_conn, params) do
    params = default_params(params)

    records = [
      {"Peak users", get_top(~w(aggregates stats peak_user_counts total), params)},
      {"Peak players", get_top(~w(aggregates stats peak_user_counts player), params)},
      {"Unique users", get_top(~w(aggregates stats unique_users), params)},
      {"Unique players", get_top(~w(aggregates stats unique_players), params)},
      {"Accounts created", get_top(~w(aggregates stats accounts_created), params)},
      {"Total time (days)", get_top(~w(aggregates minutes total), params) |> minutes_to_days},
      {"Player time (days)", get_top(~w(aggregates minutes player), params) |> minutes_to_days}
    ]

    force_recache = Map.get(params, "recache", false) == "true"
    today = Logging.get_todays_server_log(force_recache)

    today_data = %{
      "Peak users" => today["aggregates"]["stats"]["peak_user_counts"]["total"],
      "Peak players" => today["aggregates"]["stats"]["peak_user_counts"]["player"],
      "Unique users" => today["aggregates"]["stats"]["unique_users"],
      "Unique players" => today["aggregates"]["stats"]["unique_players"],
      "Accounts created" => today["aggregates"]["stats"]["accounts_created"],
      "Total time (days)" => today["aggregates"]["minutes"]["total"] |> Kernel.div(1440) |> round,
      "Player time (days)" =>
        today["aggregates"]["minutes"]["player"] |> Kernel.div(1440) |> round
    }

    %{
      presets: DatePresets.long_ranges(),
      top_count: @top_count,
      records: records,
      params: params,
      today: today_data
    }
  end

  defp get_top(fields, params) do
    path =
      fields
      |> Enum.map_join(" -> ", fn f -> "'#{f}'" end)

    {start_date, _end_date} =
      DatePresets.parse(
        params["date_preset"],
        "",
        ""
      )

    query = """
      SELECT
        logs.date,
        logs.data -> #{path}
      FROM teiserver_server_day_logs logs
      WHERE logs.date > $2
      ORDER BY
        (logs.data -> #{path}) DESC
      LIMIT $1
    """

    case Ecto.Adapters.SQL.query(Repo, query, [@top_count, start_date]) do
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

  def default_params(params) do
    Map.merge(
      %{
        "date_preset" => "Last 12 months"
      },
      params["report"] || %{}
    )
  end
end
