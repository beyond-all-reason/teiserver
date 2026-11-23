defmodule Teiserver.Account.GrowthReport do
  @moduledoc false

  alias Teiserver.Helper.DateHelper
  alias Teiserver.Logging

  @doc """
    Builds multi series maps for `LiveCharts.chart`, takes a time unit ("Day", "Week", "Month", "Quarter","Year") anything out of bounds will default to "Day".
  """
  @spec build_series(String.t(), non_neg_integer()) :: {list(), list()}
  def build_series(time_unit, log_count)
      when is_binary(time_unit) and is_integer(log_count) and log_count >= 0 do
    series = [
      %{
        title: "Unique counts",
        series_options: [
          %{
            name: "Unique users",
            paths: [~w"aggregates stats unique_users"]
          },
          %{
            name: "Unique players",
            paths: [~w"aggregates stats unique_players"]
          }
        ]
      },
      %{
        title: "Peak counts",
        series_options: [
          %{
            name: "Peak users",
            paths: [~w"aggregates stats peak_user_counts total"]
          },
          %{
            name: "Peak players",
            paths: [~w"aggregates stats peak_user_counts player"]
          },
          %{
            name: "Accounts created",
            paths: [~w"aggregates stats accounts_created"]
          }
        ]
      },
      %{
        title: "Time counts",
        series_options: [
          %{
            name: "Total minutes",
            paths: [~w"aggregates minutes total"],
            post_processor: fn x ->
              round(x / 60 / 24)
            end
          },
          %{
            name: "Player minutes",
            paths: [~w"aggregates minutes player"],
            post_processor: fn x ->
              round(x / 60 / 24)
            end
          }
        ]
      },
      %{
        title: "PvP Matches",
        series_options: [
          %{
            name: "Duels",
            paths: [~w"matches counts duel"]
          },
          %{
            name: "Team games",
            paths: [~w"matches counts team"]
          },
          %{
            name: "Small Team games",
            paths: [~w"matches counts small_team"]
          },
          %{
            name: "Large Team games",
            paths: [~w"matches counts large_team"]
          },
          %{
            name: "FFA games",
            paths: [~w"matches counts ffa"]
          }
        ]
      },
      %{
        title: "PVE matches",
        series_options: [
          %{
            name: "Bot matches",
            paths: [~w"matches counts bots"]
          },
          %{
            name: "Raptor matches",
            paths: [~w"matches counts raptors"]
          },
          %{
            name: "Scavengers matches",
            paths: [~w"matches counts scavengers"]
          }
        ]
      },
      %{
        title: "Singleplayer",
        series_options: [
          %{
            name: "Scenarios started",
            paths: [
              ~w"events complex_anon game_start:singleplayer:scenario_start",
              ~w"events complex_client game_start:singleplayer:scenario_start"
            ]
          },
          %{
            name: "Skirmishes",
            paths: [
              ~w"events complex_anon game_start:singleplayer:lone_other_skirmish",
              ~w"events complex_client game_start:singleplayer:lone_other_skirmish"
            ]
          }
        ]
      }
    ]

    case get_server_logs(time_unit, log_count) do
      [] ->
        {[], []}

      logs ->
        date_keys = Enum.map(logs, fn log -> log.date |> DateHelper.date_to_str(format: :ymd) end)
        series = Enum.map(series, fn sh -> create_series(logs, sh) end)
        {date_keys, series}
    end
  end

  defp get_server_logs(time_unit, limit) do
    logs =
      case time_unit do
        "Day" ->
          Logging.list_server_day_logs(
            order: "Newest first",
            limit: limit
          )

        "Week" ->
          Logging.list_server_week_logs(
            order: "Newest first",
            limit: limit
          )

        "Month" ->
          Logging.list_server_month_logs(
            order: "Newest first",
            limit: limit
          )

        "Quarter" ->
          Logging.list_server_quarter_logs(
            order: "Newest first",
            limit: limit
          )

        "Year" ->
          Logging.list_server_year_logs(
            order: "Newest first",
            limit: limit
          )
      end

    Enum.reverse(logs)
  end

  defp create_series(logs, %{title: title, series_options: series_options}) do
    %{title: title, series: construct_series(logs, series_options)}
  end

  defp construct_series(logs, list_of_paths_and_names) when is_list(list_of_paths_and_names) do
    Enum.map(list_of_paths_and_names, fn %{name: name, paths: paths} = options ->
      if Map.has_key?(options, :post_processor) do
        construct_series(logs, paths, name, options.post_processor)
      else
        construct_series(logs, paths, name)
      end
    end)
  end

  # in case of more than one path reduce the values, back off to 0 if nil
  defp construct_series(logs, paths, name, post_processor \\ nil) when is_list(paths) do
    data =
      Enum.map(logs, fn log ->
        Enum.reduce(paths, 0, fn path, acc ->
          value = get_in(log.data, path) || 0
          acc + value
        end)
      end)

    data =
      if post_processor do
        Enum.map(data, post_processor)
      else
        data
      end

    %{data: data, name: name}
  end
end
