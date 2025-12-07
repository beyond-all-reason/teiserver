defmodule Teiserver.Account.WeekOnWeekReport do
  alias Teiserver.{Logging}
  alias Teiserver.Helper.{TimexHelper, NumberHelper}

  @spec icon() :: String.t()
  def icon(), do: "fa-solid fa-calendar"

  @spec permissions() :: String.t()
  def permissions(), do: "Admin"

  @spec run(Plug.Conn.t(), map()) :: map()
  def run(_conn, params) do
    params = apply_defaults(params)

    start_date =
      Timex.now()
      |> Timex.beginning_of_week()
      |> Timex.shift(weeks: -5)

    logs =
      Logging.list_server_day_logs(
        search: [
          start_date: start_date
        ],
        order_by: "Oldest first"
      )

    data_map =
      logs
      |> Map.new(fn log ->
        {_, week} = Timex.iso_week(log.date)
        weekday = Timex.weekday(log.date)

        key = {week, weekday}
        value = get_metric(log.data, params["metric"])

        {key, value}
      end)

    delta_map =
      data_map
      |> Map.new(fn {{week, weekday} = key, this_value} ->
        previous_key = {week - 1, weekday}
        previous_value = data_map[previous_key]

        if previous_value not in [nil, 0] do
          delta = NumberHelper.percent(this_value / previous_value) - 100

          {key, delta}
        else
          {key, nil}
        end
      end)

    weeks =
      Map.keys(data_map)
      |> Enum.map(fn {week, _day} ->
        week
      end)
      |> Enum.uniq()
      |> Enum.sort_by(fn v -> v end, &>=/2)
      |> Enum.take(5)

    week_data =
      Logging.list_server_week_logs(
        search: [
          start_date: start_date |> Timex.shift(weeks: -2)
        ]
      )
      |> Map.new(fn log ->
        key = log.week
        value = get_metric(log.data, params["metric"])

        {key, value}
      end)

    week_deltas =
      week_data
      |> Map.new(fn {key, this_value} ->
        previous_key = key - 1
        previous_value = week_data[previous_key]

        if previous_value not in [nil, 0] do
          delta = NumberHelper.percent(this_value / previous_value) - 100

          {key, delta}
        else
          {key, nil}
        end
      end)

    formatter =
      case params["metric"] do
        "Total time" -> &TimexHelper.represent_minutes/1
        "Play time" -> &TimexHelper.represent_minutes/1
        _ -> fn x -> x end
      end

    data_map =
      data_map
      |> Map.new(fn {k, v} ->
        {k, formatter.(v)}
      end)

    %{
      data_map: data_map,
      delta_map: delta_map,
      week_deltas: week_deltas,
      week_data: week_data,
      weeks: weeks,
      params: params
    }
  end

  defp apply_defaults(params) do
    Map.get(params, "report", %{
      "metric" => "Unique users"
    })
  end

  defp get_metric(data, "Unique users"), do: data["aggregates"]["stats"]["unique_users"] || 0
  defp get_metric(data, "Unique players"), do: data["aggregates"]["stats"]["unique_players"] || 0

  defp get_metric(data, "Peak users"),
    do: data["aggregates"]["stats"]["peak_user_counts"]["total"] || 0

  defp get_metric(data, "Peak players"),
    do: data["aggregates"]["stats"]["peak_user_counts"]["player"] || 0

  defp get_metric(data, "Total time"), do: data["aggregates"]["minutes"]["total"] || 0
  defp get_metric(data, "Play time"), do: data["aggregates"]["minutes"]["player"] || 0
  defp get_metric(data, "Registrations"), do: data["aggregates"]["stats"]["accounts_created"] || 0
end
