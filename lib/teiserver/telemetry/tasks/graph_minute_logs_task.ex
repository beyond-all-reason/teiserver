defmodule Teiserver.Telemetry.GraphMinuteLogsTask do
  @spec perform_players(list) :: list()
  def perform_players(logs) do
    [
      ["Users" | Enum.map(logs, fn l -> l.data["client"]["total"] |> Enum.count end)],
      ["Players" | Enum.map(logs, fn l -> l.data["client"]["player"] |> Enum.count end)]
    ]
  end

  @spec perform_matches(list) :: list()
  def perform_matches(logs) do
    [
      ["Matches lobby" | Enum.map(logs, fn l -> l.data["battle"]["lobby"] end)],
      ["Matches ongoing" | Enum.map(logs, fn l -> l.data["battle"]["in_progress"] end)]
    ]
  end

  @spec perform_matches_start_stop(list) :: list()
  def perform_matches_start_stop(logs) do
    [
      ["Matches started" | Enum.map(logs, fn l -> l.data["battle"]["started"] end)],
      ["Matches stopped" | Enum.map(logs, fn l -> l.data["battle"]["stopped"] end)]
    ]
  end

  @spec perform_user_connections(list) :: list()
  def perform_user_connections(logs) do
    [
      ["User Connects" | Enum.map(logs, fn l -> l.data["server"]["users_connected"] end)],
      ["User Disconnects" | Enum.map(logs, fn l -> l.data["server"]["users_disconnected"] end)]
    ]
  end

  @spec perform_bot_connections(list) :: list()
  def perform_bot_connections(logs) do
    [
      ["Bot Connects" | Enum.map(logs, fn l -> l.data["server"]["bots_connected"] end)],
      ["Bot Disconnects" | Enum.map(logs, fn l -> l.data["server"]["bots_disconnected"] end)]
    ]
  end

  @spec perform_combined_connections(list) :: list()
  def perform_combined_connections(logs) do
    [
      ["User Connects" | Enum.map(logs, fn l -> l.data["server"]["users_connected"] + l.data["server"]["bots_connected"] end)],
      ["User Disconnects" | Enum.map(logs, fn l -> l.data["server"]["users_disconnected"] + l.data["server"]["bots_disconnected"] end)]
    ]
  end

  # Gigabytes
  @memory_div (1024*1024*1024)

  @spec perform_memory(list) :: list()
  def perform_memory(logs) do
    [
      ["Total" | Enum.map(logs, fn l ->
        m = l.data["os_mon"]["system_mem"]["total_memory"]
        m/@memory_div
      end)],
      ["Used" | Enum.map(logs, fn l ->
        total = l.data["os_mon"]["system_mem"]["total_memory"]
        free = l.data["os_mon"]["system_mem"]["free_memory"]
        cached = l.data["os_mon"]["system_mem"]["cached_memory"]
        buffered = l.data["os_mon"]["system_mem"]["buffered_memory"]

        m = total - (free + cached + buffered)
        m/@memory_div
      end)]
    ]
  end

  @spec perform_cpu(list) :: list()
  def perform_cpu(logs) do
    [
      ["CPU Load 1" | Enum.map(logs, fn l -> l.data["os_mon"]["cpu_avg1"] end)],
      ["CPU Load 5" | Enum.map(logs, fn l -> l.data["os_mon"]["cpu_avg5"] end)],
      ["CPU Load 15" | Enum.map(logs, fn l -> l.data["os_mon"]["cpu_avg15"] end)]
    ]
  end
end
