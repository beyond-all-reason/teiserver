defmodule Teiserver.Account.GrowthReport do
  @moduledoc false
  alias Teiserver.{Telemetry}
  alias Central.Helpers.{TimexHelper}
  import Central.Helpers.NumberHelper, only: [int_parse: 1]
  alias Teiserver.Telemetry.ServerGraphDayLogsTask
  require Logger

  @spec icon() :: String.t()
  def icon(), do: "fa-regular fa-seedling"

  @spec permissions() :: String.t()
  def permissions(), do: "teiserver.staff.moderator"

  @spec run(Plug.Conn.t(), map()) :: {map(), map()}
  def run(_conn, params) do
    params = apply_defaults(params)

    days = params["days"]
      |> int_parse

    server_data = get_server_metrics(days)

    assigns = %{
      params: params
    }
    |> Map.merge(server_data)

    {%{}, assigns}
  end

  defp apply_defaults(params) do
    Map.merge(
      %{
        "days" => "31",
        "columns" => "1"
      },
      Map.get(params, "report", %{})
    )
  end

  # defp get_server_metrics(days) do
  #   logs =
  #     Telemetry.list_server_day_logs(
  #       order: "Newest first",
  #       limit: days
  #     )
  #     |> Enum.reverse()

  #   # Peak counts
  #   field_list = ["aggregates.stats.peak_user_counts.total", "aggregates.stats.peak_user_counts.player", "aggregates.stats.accounts_created"]
  #   columns = ServerGraphDayLogsTask.perform(logs, %{"field_list" => field_list}, fn x -> x end)

  #   key = logs
  #     |> Enum.map(fn log -> log.date |> TimexHelper.date_to_str(format: :ymd) end)

  #   peak_counts = {key, columns}

  #   IO.puts ""
  #   IO.inspect peak_counts
  #   IO.puts ""


  #   %{
  #     unique_counts: {[], []},
  #     peak_counts: {[], []},
  #     time_counts: {[], []},
  #   }
  # end

  defp get_server_metrics(days) do
    logs =
      Telemetry.list_server_day_logs(
        order: "Newest first",
        limit: days
      )
      |> Enum.reverse()

    # Unique counts
    field_list = [
      {"Unique users", "aggregates.stats.unique_users"},
      {"Unique players", "aggregates.stats.unique_players"}
    ]
    columns = ServerGraphDayLogsTask.perform(logs, %{"field_list" => field_list}, fn x -> x end)

    key = logs
      |> Enum.map(fn log -> log.date |> TimexHelper.date_to_str(format: :ymd) end)

    unique_counts = {key, columns}

    # Peak counts
    field_list = [
      {"Peak users", "aggregates.stats.peak_user_counts.total"},
      {"Peak players", "aggregates.stats.peak_user_counts.player"},
      {"Accounts created", "aggregates.stats.accounts_created"}
    ]
    columns = ServerGraphDayLogsTask.perform(logs, %{"field_list" => field_list}, fn x -> x end)

    key = logs
      |> Enum.map(fn log -> log.date |> TimexHelper.date_to_str(format: :ymd) end)

    peak_counts = {key, columns}

    # Time counts
    field_list = [
        {"Player days", "aggregates.minutes.player"},
        {"Total days", "aggregates.minutes.total"}
    ]
    columns = ServerGraphDayLogsTask.perform(logs, %{"field_list" => field_list}, fn x -> round(x/60/24) end)

    key = logs
      |> Enum.map(fn log -> log.date |> TimexHelper.date_to_str(format: :ymd) end)

    time_counts = {key, columns}

    # PvP Matches
    field_list = [
      {"Duels", "matches.counts.duel"},
      {"Team games", "matches.counts.team"},
      {"FFA games", "matches.counts.ffa"}
    ]
    columns = ServerGraphDayLogsTask.perform(logs, %{"field_list" => field_list}, fn x -> x end)

    key = logs
      |> Enum.map(fn log -> log.date |> TimexHelper.date_to_str(format: :ymd) end)

    pvp_counts = {key, columns}

    # PvE Matches
    field_list = [
      {"Bot matches", "matches.counts.bots"},
      {"Raptor matches", "matches.counts.raptors"},
      {"Scavengers matches", "matches.counts.scavengers"}
    ]
    columns = ServerGraphDayLogsTask.perform(logs, %{"field_list" => field_list}, fn x -> x end)

    key = logs
      |> Enum.map(fn log -> log.date |> TimexHelper.date_to_str(format: :ymd) end)

    pve_counts = {key, columns}

    # Combined events
    field_list = [
      {"Scenarios started", "events.combined.game_start:singleplayer:scenario_start"},
      {"Skirmishes", "events.combined.game_start:singleplayer:lone_other_skirmish"},
    ]
    columns = ServerGraphDayLogsTask.perform(logs, %{"field_list" => field_list}, fn x -> x end)

    key = logs
      |> Enum.map(fn log -> log.date |> TimexHelper.date_to_str(format: :ymd) end)

    singleplayer_counts = {key, columns}

    # data = hd(logs).data["events"]["combined"]
    # IO.puts ""
    # IO.inspect data
    # IO.inspect data |> Map.keys
    # IO.puts ""

    %{
      unique_counts: unique_counts,
      peak_counts: peak_counts,
      time_counts: time_counts,
      pvp_counts: pvp_counts,
      pve_counts: pve_counts,
      singleplayer_counts: singleplayer_counts
    }
  end
end
