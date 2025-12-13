defmodule Teiserver.Account.GrowthReport do
  @moduledoc false
  @behaviour Teiserver.Common.WebReportBehaviour
  alias Teiserver.Logging
  alias Teiserver.Helper.ChartHelper
  import Teiserver.Helper.NumberHelper, only: [int_parse: 1]
  require Logger

  @spec name() :: String.t()
  def name(), do: "Growth"

  @spec icon() :: String.t()
  def icon(), do: "fa-solid fa-seedling"

  @spec permissions() :: String.t()
  def permissions(), do: "Admin"

  @spec run(Plug.Conn.t(), map()) :: map()
  def run(_conn, params) do
    params = apply_defaults(params)

    limit =
      params["limit"]
      |> int_parse()

    server_data =
      get_server_logs(params["time_unit"], limit)
      |> get_server_metrics()

    Map.merge(server_data, %{
      params: params
    })
  end

  defp apply_defaults(params) do
    Map.merge(
      %{
        "limit" => "31",
        "columns" => "1",
        "time_unit" => "Day"
      },
      Map.get(params, "report", %{})
    )
  end

  defp get_server_metrics(logs) do
    date_keys = ChartHelper.extract_keys(logs, :date, "x")

    # Unique counts
    unique_counts =
      ChartHelper.build_lines(logs, [
        %{
          name: "Unique users",
          paths: [~w"aggregates stats unique_users"]
        },
        %{
          name: "Unique players",
          paths: [~w"aggregates stats unique_players"]
        }
      ])

    # Peak counts
    peak_counts =
      ChartHelper.build_lines(logs, [
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
      ])

    # Time counts
    time_counts =
      ChartHelper.build_lines(logs, [
        %{
          name: "Player minutes",
          paths: [~w"aggregates minutes player"],
          post_processor: fn x ->
            round(x / 60 / 24)
          end
        },
        %{
          name: "Total minutes",
          paths: [~w"aggregates minutes total"],
          post_processor: fn x ->
            round(x / 60 / 24)
          end
        }
      ])

    # PvP Matches
    pvp_counts =
      ChartHelper.build_lines(logs, [
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
      ])

    # PvE Matches
    pve_counts =
      ChartHelper.build_lines(logs, [
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
      ])

    # Singleplayer
    singleplayer_counts =
      ChartHelper.build_lines(logs, [
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
      ])

    %{
      unique_counts: [date_keys | unique_counts],
      peak_counts: [date_keys | peak_counts],
      time_counts: [date_keys | time_counts],
      pvp_counts: [date_keys | pvp_counts],
      pve_counts: [date_keys | pve_counts],
      singleplayer_counts: [date_keys | singleplayer_counts]
    }
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
end
