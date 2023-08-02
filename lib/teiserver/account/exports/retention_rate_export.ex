defmodule Teiserver.Account.RetentionRateExport do
  @moduledoc """
  Can be manually run with:
  Teiserver.Account.RetentionRateExport.show_form(nil, %{
    "date_preset" => "All time",
    "end_date" => "",
    "rating_type" => "user_count_total",
    "start_date" => ""
  })

  Teiserver.Account.RetentionRateExport.show_form(nil, %{
    "date_preset" => "All time",
    "end_date" => "",
    "rating_type" => "user_count_total",
    "start_date" => "2023-01-01"
  })
  """
  alias Teiserver.Helper.DatePresets
  alias Teiserver.{Account, Logging}
  alias Teiserver.Helper.TimexHelper
  alias Teiserver.Helper.TimexHelper
  require Logger

  @activity_types ~w(total player)

  @spec icon() :: String.t()
  def icon(), do: "fa-regular fa-campground"

  @spec permissions() :: String.t()
  def permissions(), do: "Admin"

  @spec show_form(Plug.Conn.t()) :: map()
  def show_form(_conn) do
    %{
      params: %{},
      presets: DatePresets.short_ranges()
    }
  end

  def show_form(_conn, params) do
    start_time = System.system_time(:second)
    params = apply_defaults(params)

    # Date range
    {start_date, end_date} =
      DatePresets.parse(
        params["date_preset"],
        params["start_date"],
        params["end_date"]
      )

    start_datetime = Timex.to_datetime(start_date)
    end_datetime = Timex.to_datetime(end_date)
    today_datetime = Timex.today() |> Timex.to_datetime()

    end_datetime =
      if Timex.compare(today_datetime, end_datetime) == 1 do
        end_datetime
      else
        today_datetime
      end

    day_logs =
      Logging.list_user_activity_day_logs(
        search: [start_date: start_date],
        order: "Newest first",
        limit: :infinity
      )
      |> Map.new(fn log ->
        {log.date, log.data}
      end)

    # Get the accounts then calculate their last played time
    # account must have at least logged in and been verified
    accounts_by_insert_date =
      Account.list_users(
        search: [
          inserted_after: start_datetime,
          inserted_before: end_datetime,
          verified: true,
          data_greater_than: {"last_login_mins", "0"},
          bot: "Person"
        ],
        select: [:id, :inserted_at],
        limit: :infinity
      )
      |> Enum.group_by(
        fn user ->
          Timex.to_date(user.inserted_at)
        end,
        fn user ->
          to_string(user.id)
        end
      )
      |> Enum.map(fn {key, userids} -> {key, userids} end)
      |> Enum.sort_by(fn {key, _} -> TimexHelper.date_to_str(key, format: :ymd) end, &<=/2)

    data = build_table(day_logs, accounts_by_insert_date)

    end_time = System.system_time(:second)
    time_taken = end_time - start_time
    Logger.info("Ran #{__MODULE__} export in #{time_taken}s")

    return_content(data, params)
  end

  defp add_csv_headings(output, dates) do
    headings = [
      [
        "Date",
        "Registration count"
      ] ++ for(d <- dates, do: TimexHelper.date_to_str(d, format: :ymd))
    ]

    headings ++ output
  end

  defp make_csv_cell(date, row, params) do
    if row[date] == nil do
      ""
    else
      case params["csv_value"] do
        "time_player" ->
          row[date].total_times["player"]

        "time_total" ->
          row[date].total_times["total"]

        "user_count_player" ->
          row[date].user_counts["player"]

        _user_count_total ->
          row[date].user_counts["total"]
      end
    end
  end

  defp return_content(data, %{"format" => "csv"} = params) do
    dates =
      Map.keys(data)
      |> Enum.sort_by(fn key -> TimexHelper.date_to_str(key, format: :ymd) end, &<=/2)

    csv_output =
      dates
      |> Stream.map(fn date ->
        row = data[date]

        [
          TimexHelper.date_to_str(date, format: :ymd),
          row.registration_count
        ] ++ for d <- dates, do: make_csv_cell(d, row, params)
      end)
      |> Enum.to_list()
      |> add_csv_headings(dates)
      |> CSV.encode()
      |> Enum.to_list()

    path = "/tmp/retention_rate.csv"
    File.write(path, csv_output)
    {:file, path, "retention_rate.csv", "text/csv"}
  end

  defp return_content(data, %{"format" => "json"}) do
    content_type = "application/json"
    path = "/tmp/retention_rate.json"
    File.write(path, Jason.encode_to_iodata!(data))
    {:file, path, "retention_rate.json", content_type}
  end

  # Build the table as a whole
  defp build_table(day_logs, accounts_by_insert_date) do
    accounts_by_insert_date
    |> Map.new(fn {date, userids} ->
      Logger.debug("Building row for #{date}")

      data =
        build_data_row(userids, day_logs)
        |> Map.merge(%{
          registration_count: Enum.count(userids)
        })

      {date, data}
    end)
  end

  # Build the data for a single date (row) in the table
  # date refers to the date of registration for the users in this group
  defp build_data_row(userids, day_logs) do
    day_logs
    |> Map.new(fn {date, log_data} ->
      {date, build_data_cell(userids, log_data)}
    end)
  end

  # This will be the cell data for users registered on reg_date
  # for the data in log_data from a given date
  defp build_data_cell(userids, log_data) do
    user_counts =
      @activity_types
      |> Map.new(fn activity ->
        result =
          log_data[activity]
          |> Enum.map(fn {str_id, _mins} ->
            if Enum.member?(userids, str_id), do: 1, else: 0
          end)
          |> Enum.sum()

        {activity, result}
      end)

    total_times =
      @activity_types
      |> Map.new(fn activity ->
        result =
          log_data[activity]
          |> Enum.map(fn {str_id, mins} ->
            if Enum.member?(userids, str_id), do: mins, else: 0
          end)
          |> Enum.sum()

        {activity, result}
      end)

    %{
      user_counts: user_counts,
      total_times: total_times
    }
  end

  defp apply_defaults(params) do
    Map.merge(
      %{
        "date_preset" => "This week",
        "start_date" => "",
        "end_date" => "",
        "format" => "csv",
        "csv_value" => "user_count_total"
      },
      params
    )
  end
end
