defmodule Teiserver.Account.PlayerCountExport do
  @moduledoc """
  Can be manually run with:
  Teiserver.Game.MatchRatingsExport.show_form(nil, %{
    "date_preset" => "All time",
    "end_date" => "",
    "rating_type" => "Large Team",
    "start_date" => ""
  })
  """
  alias Teiserver.Helper.DatePresets
  alias Teiserver.Logging
  alias Teiserver.Helper.TimexHelper

  @spec icon() :: String.t()
  def icon(), do: "fa-solid fa-users"

  @spec permissions() :: String.t()
  def permissions(), do: "Admin"

  @spec show_form(Plug.Conn.t()) :: map()
  def show_form(_conn) do
    %{
      params: %{},
      presets: DatePresets.long_presets()
    }
  end

  defp get_defaults(params) do
    Map.merge(
      %{
        "format" => "csv",
        "table" => "Daily"
      },
      params
    )
  end

  def show_form(_conn, params) do
    params = get_defaults(params)

    {start_date, end_date} =
      DatePresets.parse(
        params["date_preset"],
        params["start_date"],
        params["end_date"]
      )

    start_date = Timex.to_datetime(start_date)
    end_date = Timex.to_datetime(end_date)

    {content_type, ext} =
      case params["format"] do
        "json" -> {"application/json", "json"}
        "csv" -> {"text/csv", "csv"}
      end

    list_func =
      case params["table"] do
        "Daily" -> &Logging.list_server_day_logs/1
        "Weekly" -> &Logging.list_server_week_logs/1
        "Monthly" -> &Logging.list_server_month_logs/1
        "Quarterly" -> &Logging.list_server_quarter_logs/1
        "Yearly" -> &Logging.list_server_year_logs/1
      end

    data =
      list_func.(
        search: [
          start_date: start_date,
          end_date: end_date
        ],
        limit: :infinity,
        order: "Oldest first"
      )
      |> do_output(params)

    path = "/tmp/player_count_export.#{ext}"
    File.write(path, data)
    {:file, path, "player_count.#{ext}", content_type}
  end

  defp do_output(data, %{"format" => "json"} = _params) do
    data
    |> Stream.map(fn log ->
      log.data
      |> Map.drop(["minutes_per_user", "old_minutes_per_user"])
      |> Map.put("date", log.date)
    end)
    |> Enum.to_list()
    |> Jason.encode_to_iodata!()
  end

  defp do_output(data, %{"format" => "csv"} = _params) do
    data
    |> Stream.map(fn log ->
      [
        log.date |> TimexHelper.date_to_str(format: :ymd),
        get_in(log.data, ~w(aggregates stats unique_users)),
        get_in(log.data, ~w(aggregates stats unique_players)),
        get_in(log.data, ~w(aggregates stats peak_user_counts total)),
        get_in(log.data, ~w(aggregates stats peak_user_counts player)),
        get_in(log.data, ~w(aggregates minutes menu)),
        get_in(log.data, ~w(aggregates minutes lobby)),
        get_in(log.data, ~w(aggregates minutes spectator)),
        get_in(log.data, ~w(aggregates minutes player)),
        get_in(log.data, ~w(aggregates minutes total)),
        get_in(log.data, ~w(aggregates stats accounts_created))
      ]
    end)
    |> Enum.to_list()
    |> add_csv_headings()
    |> CSV.encode()
    |> Enum.to_list()
  end

  defp add_csv_headings(output) do
    headings = [
      [
        "Date",
        "Unique users",
        "Unique players",
        "Peak users",
        "Peak players",
        "Menu time (mins)",
        "Lobby time (mins)",
        "Spectator time (mins)",
        "Play time (mins)",
        "Total time (mins)",
        "Registrations"
      ]
    ]

    headings ++ output
  end
end
