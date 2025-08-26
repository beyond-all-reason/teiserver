defmodule Teiserver.Account.RetentionReport do
  alias Teiserver.Helper.DatePresets
  alias Teiserver.{Account, Logging}

  @spec icon() :: String.t()
  def icon(), do: "fa-solid fa-campground"

  @spec permissions() :: String.t()
  def permissions(), do: "Admin"

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

    day_logs =
      Logging.list_user_activity_day_logs(
        search: [start_date: start_date],
        order: "Newest first",
        limit: :infinity
      )

    # Get the accounts then calculate their last played time
    accounts =
      Account.list_users(
        search: [
          inserted_after: start_datetime,
          data_greater_than: {"last_login_mins", "0"},
          verified: true
        ],
        limit: :infinity
      )
      |> Enum.map(fn user ->
        last_login = user.last_login

        last_played =
          day_logs
          |> Enum.reduce(nil, fn log, acc ->
            case acc do
              nil ->
                if log.data["player"][to_string(user.id)] do
                  log.date
                else
                  nil
                end

              _ ->
                acc
            end
          end)

        if last_played != nil and last_login != nil do
          %{
            last_login: Timex.diff(user.inserted_at, last_login, :days) |> abs,
            last_played: Timex.diff(user.inserted_at, last_played, :days) |> abs
          }
        end
      end)
      |> Enum.reject(&(&1 == nil))

    # Grouping 1 - Last login
    login_retention =
      accounts
      |> Enum.group_by(
        fn %{last_login: value} ->
          value
        end,
        fn _ -> 1 end
      )
      |> Map.new(fn {days, userlist} -> {days, Enum.count(userlist)} end)

    # Grouping 2 - Last time played
    play_retention_grouping =
      accounts
      |> Enum.group_by(
        fn %{last_played: value} ->
          value
        end,
        fn _ -> 1 end
      )
      |> Map.new(fn {days, userlist} -> {days, Enum.count(userlist)} end)

    # Skip0 ?
    login_retention =
      if skip0 do
        login_retention |> Map.put(0, 0)
      else
        login_retention
      end

    play_retention_grouping =
      if skip0 do
        play_retention_grouping |> Map.put(0, 0)
      else
        play_retention_grouping
      end

    graph_data = [
      ["Login" | build_line(login_retention)],
      ["Play" | build_line(play_retention_grouping)]
    ]

    %{
      params: params,
      presets: DatePresets.long_ranges(),
      user_count: Enum.count(accounts),
      play_retention_grouping: play_retention_grouping,
      max_key: @max_key,
      graph_data: graph_data
    }
  end

  @spec build_line(map()) :: list()
  defp build_line(value_map) do
    for key <- Range.new(0, @max_key), do: Map.get(value_map, key, 0)
  end

  defp apply_defaults(params) do
    Map.merge(
      %{
        "date_preset" => "Last 3 months",
        "start_date" => "",
        "end_date" => "",
        "skip0" => "true"
      },
      Map.get(params, "report", %{})
    )
  end
end
