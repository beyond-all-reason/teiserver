defmodule Teiserver.Telemetry.GraphMinuteLogsTask do
  @spec perform_players(list) :: list()
  def perform_players(logs) do
    [
      ["Users" | Enum.map(logs, fn l -> l.data["client"]["total"] |> Enum.count end)],
      ["Players" | Enum.map(logs, fn l -> l.data["client"]["player"] |> Enum.count end)]
    ]
  end

  def perform_matches(logs) do
    [
      ["Matches lobby" | Enum.map(logs, fn l -> l.data["battle"]["lobby"] end)],
      ["Matches ongoing" | Enum.map(logs, fn l -> l.data["battle"]["in_progress"] end)]
    ]
  end

  def perform_matches_start_stop(logs) do
    [
      ["Matches started" | Enum.map(logs, fn l -> l.data["battle"]["started"] end)],
      ["Matches stopped" | Enum.map(logs, fn l -> l.data["battle"]["stopped"] end)]
    ]
  end

  def perform_user_connections(logs) do
    [
      ["User Connects" | Enum.map(logs, fn l -> l.data["server"]["users_connected"] end)],
      ["User Disconnects" | Enum.map(logs, fn l -> l.data["server"]["users_disconnected"] end)]
    ]
  end

  def perform_bot_connections(logs) do
    [
      ["Bot Connects" | Enum.map(logs, fn l -> l.data["server"]["bots_connected"] end)],
      ["Bot Disconnects" | Enum.map(logs, fn l -> l.data["server"]["bots_disconnected"] end)]
    ]
  end

  def perform_load(logs) do
    [
      ["Load" | Enum.map(logs, fn l -> l.data["server"]["load"] end)]
    ]
  end
end
