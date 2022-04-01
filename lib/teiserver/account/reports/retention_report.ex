defmodule Teiserver.Account.RetentionReport do
  alias Central.Helpers.DatePresets
  alias Teiserver.{Account, Telemetry}

  @spec icon() :: String.t()
  def icon(), do: "far fa-campground"

  @max_key 30

  @doc """
  Gets a list of players that:
    - Have logged in
    - Are verified
    - Registered within a certain date range
    - Have played at least once
  and splits them into groups of how long after they registered they last played
  """
  @spec run(Plug.Conn.t(), map()) :: {map(), map()}
  def run(_conn, params) do
    params = apply_defaults(params)
    skip0 = params["skip0"] == "true"

    # Date range
    {start_date, _end_date} =
      DatePresets.parse(
        params["date_preset"],
        params["start_date"],
        params["end_date"]
      )

    start_datetime = Timex.to_datetime(start_date)

    day_logs = Telemetry.list_server_day_logs(search: [start_date: start_date], order: "Newest first", limit: :infinity)

    # Get the accounts then calculate their last played time
    accounts = Account.list_users(
      search: [
        inserted_after: start_datetime,
        data_greater_than: {"last_login", "0"},
        data_equal: {"verified", "true"}
      ],
      limit: :infinity
    )
    |> Enum.map(fn user ->
      last_played = day_logs
      |> Enum.reduce(nil, fn (log, acc) ->
        case acc do
          nil ->
            if log.data["minutes_per_user"]["player"][to_string(user.id)] do
              log.date
            else
              nil
            end
          _ ->
            acc
        end
      end)

      Map.merge(user, %{
        last_played: last_played
      })
    end)
    |> Enum.filter(fn user -> user.last_played != nil end)

    # Grouping 1 - Last time played
    play_retention_grouping = accounts
      |> Enum.group_by(fn user ->
        Timex.diff(user.inserted_at, user.last_played, :day) |> abs
      end)
      |> Map.new(fn {days, userlist} -> {days, Enum.count(userlist)} end)

    play_retention_grouping = if skip0 do
      play_retention_grouping |> Map.put(0, 0)
    else
      play_retention_grouping
    end

    graph_data = [
      ["Play" | build_line(play_retention_grouping)],
    ]

    assigns = %{
      params: params,
      presets: DatePresets.long_ranges()
    }

    {%{
      user_count: Enum.count(accounts),
      play_retention_grouping: play_retention_grouping,
      max_key: @max_key,
      graph_data: graph_data
    }, assigns}
  end

  @spec build_line(map()) :: list()
  defp build_line(value_map) do
    for key <- Range.new(0, @max_key), do: Map.get(value_map, key, 0)
  end

  defp apply_defaults(params) do
    Map.merge(%{
      "date_preset" => "Last 3 months",
      "start_date" => "",
      "end_date" => "",
      "skip0" => "true"
    }, Map.get(params, "report", %{}))
  end
end
