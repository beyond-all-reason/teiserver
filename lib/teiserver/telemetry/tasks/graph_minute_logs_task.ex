defmodule Teiserver.Telemetry.GraphMinuteLogsTask do
  @moduledoc false
  alias Central.Helpers.{NumberHelper, TimexHelper}

  @spec perform_players(list, non_neg_integer()) :: list()
  def perform_players(logs, chunk_size) do
    [
      ["Total" | extract_value(logs, chunk_size, ~w(total_clients_connected))],
      ["People" | extract_value(logs, chunk_size, ~w(client total), &Enum.count/1)],
      ["Players" | extract_value(logs, chunk_size, ~w(client player), &Enum.count/1)]
    ]
  end

  @spec perform_matches(list, non_neg_integer()) :: list()
  def perform_matches(logs, chunk_size) do
    [
      ["Matches lobby" | extract_value(logs, chunk_size, ~w(battle lobby))],
      ["Matches ongoing" | extract_value(logs, chunk_size, ~w(battle in_progress))]
    ]
  end

  @spec perform_matches_start_stop(list, non_neg_integer()) :: list()
  def perform_matches_start_stop(logs, chunk_size) do
    [
      ["Matches started" | extract_value(logs, chunk_size, ~w(battle started))],
      ["Matches stopped" | extract_value(logs, chunk_size, ~w(battle stopped))]
    ]
  end

  @spec perform_user_connections(list, non_neg_integer()) :: list()
  def perform_user_connections(logs, chunk_size) do
    [
      ["User Connects" | extract_value(logs, chunk_size, ~w(server users_connected))],
      ["User Disconnects" | extract_value(logs, chunk_size, ~w(server users_disconnected))]
    ]
  end

  @spec perform_bot_connections(list, non_neg_integer()) :: list()
  def perform_bot_connections(logs, chunk_size) do
    [
      ["Bot Connects" | extract_value(logs, chunk_size, ~w(server bots_connected))],
      ["Bot Disconnects" | extract_value(logs, chunk_size, ~w(server bots_disconnected))]
    ]
  end

  @spec perform_combined_connections(list, non_neg_integer()) :: list()
  def perform_combined_connections(logs, chunk_size) do
    user_connects = extract_value(logs, chunk_size, ~w(server users_connected))
    bot_connects = extract_value(logs, chunk_size, ~w(server bots_connected))

    user_disconnects = extract_value(logs, chunk_size, ~w(server users_disconnected))
    bot_disconnects = extract_value(logs, chunk_size, ~w(server bots_disconnected))

    connected =
      [user_connects, bot_connects]
      |> Enum.zip()
      |> Enum.map(fn {u, b} -> u + b end)

    disconnected =
      [user_disconnects, bot_disconnects]
      |> Enum.zip()
      |> Enum.map(fn {u, b} -> u + b end)

    [
      ["Connects" | connected],
      ["Disconnects" | disconnected]
    ]
  end

  # Gigabytes
  @memory_div 1024 * 1024 * 1024

  @spec perform_memory(list, non_neg_integer()) :: list()
  def perform_memory(logs, chunk_size) do
    total =
      extract_value(logs, chunk_size, ~w(os_mon system_mem total_memory))
      |> Enum.map(fn v -> (v / @memory_div) |> NumberHelper.round(2) end)

    free =
      extract_value(logs, chunk_size, ~w(os_mon system_mem free_memory))
      |> Enum.map(fn v -> (v / @memory_div) |> NumberHelper.round(2) end)

    cached =
      extract_value(logs, chunk_size, ~w(os_mon system_mem cached_memory))
      |> Enum.map(fn v -> (v / @memory_div) |> NumberHelper.round(2) end)

    buffered =
      extract_value(logs, chunk_size, ~w(os_mon system_mem buffered_memory))
      |> Enum.map(fn v -> (v / @memory_div) |> NumberHelper.round(2) end)

    free_swap =
      extract_value(logs, chunk_size, ~w(os_mon system_mem free_swap))
      |> Enum.map(fn v -> (v / @memory_div) |> NumberHelper.round(2) end)

    total_swap =
      extract_value(logs, chunk_size, ~w(os_mon system_mem total_swap))
      |> Enum.map(fn v -> (v / @memory_div) |> NumberHelper.round(2) end)

    used =
      [total, free, cached, buffered]
      |> Enum.zip()
      |> Enum.map(fn {t, f, c, b} -> (t - (f + c + b)) |> NumberHelper.round(2) end)

    swap =
      [total_swap, free_swap]
      |> Enum.zip()
      |> Enum.map(fn {t, f} -> (t - f) |> NumberHelper.round(2) end)

    [
      # ["Total" | total],
      ["Used" | used],
      ["Buffered" | buffered],
      ["Cached" | cached],
      ["Swap" | swap]
    ]
  end

  @spec perform_cpu_load(list, non_neg_integer()) :: list()
  def perform_cpu_load(logs, chunk_size) do
    [
      ["CPU Load 1" | extract_value(logs, chunk_size, ~w(os_mon cpu_avg1))],
      ["CPU Load 5" | extract_value(logs, chunk_size, ~w(os_mon cpu_avg5))],
      ["CPU Load 15" | extract_value(logs, chunk_size, ~w(os_mon cpu_avg15))]
    ]
  end

  @spec perform_server_messages(list, non_neg_integer()) :: list()
  def perform_server_messages(logs, chunk_size) do
    [
      ["Server messages sent" | extract_value(logs, chunk_size, ~w(spring_server_messages_sent))],
      ["Server batches sent" | extract_value(logs, chunk_size, ~w(spring_server_batches_sent))]
    ]
  end

  @spec perform_client_messages(list, non_neg_integer()) :: list()
  def perform_client_messages(logs, chunk_size) do
    [
      ["Client messages sent" | extract_value(logs, chunk_size, ~w(spring_client_messages_sent))]
    ]
  end

  @spec perform_system_process_counts(list, non_neg_integer()) :: list()
  def perform_system_process_counts(logs, chunk_size) do
    [
      ["Throttles" | extract_value(logs, chunk_size, ~w(os_mon processes throttle_servers))],
      ["Accolades" | extract_value(logs, chunk_size, ~w(os_mon processes accolade_servers))],
      ["Lobbies" | extract_value(logs, chunk_size, ~w(os_mon processes lobby_servers))],
      ["Consuls" | extract_value(logs, chunk_size, ~w(os_mon processes consul_servers))],
      ["Balancers" | extract_value(logs, chunk_size, ~w(os_mon processes balancer_servers))],
      ["System" | extract_value(logs, chunk_size, ~w(os_mon processes system_servers))]
    ]
  end

  @spec perform_user_process_counts(list, non_neg_integer()) :: list()
  def perform_user_process_counts(logs, chunk_size) do
    [
      ["Clients" | extract_value(logs, chunk_size, ~w(os_mon processes client_servers))],
      ["Parties" | extract_value(logs, chunk_size, ~w(os_mon processes party_servers))]
    ]
  end

  @spec perform_beam_process_counts(list, non_neg_integer()) :: list()
  def perform_beam_process_counts(logs, chunk_size) do
    [
      ["Beam" | extract_value(logs, chunk_size, ~w(os_mon processes beam_total))],
      ["Teiserver" | extract_value(logs, chunk_size, ~w(os_mon processes teiserver_total))]
    ]
  end

  @spec perform_axis_key(list, non_neg_integer()) :: list()
  def perform_axis_key(logs, chunk_size) do
    logs
    |> Enum.chunk_every(chunk_size)
    |> Enum.map(fn [log | _] -> log.timestamp |> TimexHelper.date_to_str(format: :ymd_hms) end)
  end

  defp extract_value(logs, 1, path) do
    logs
    |> Enum.map(fn log ->
      get_in(log.data, path) || 0
    end)
  end

  defp extract_value(logs, chunk_size, path, func \\ fn x -> x end) do
    logs
    |> Enum.chunk_every(chunk_size)
    |> Enum.map(fn chunk ->
      result =
        chunk
        |> Enum.map(fn log ->
          get_in(log.data, path) |> func.() || 0
        end)
        |> Enum.sum()

      result / chunk_size
    end)
  end
end
