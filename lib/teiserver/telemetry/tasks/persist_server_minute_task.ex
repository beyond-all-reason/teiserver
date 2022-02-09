defmodule Teiserver.Telemetry.Tasks.PersistServerMinuteTask do
  use Oban.Worker, queue: :teiserver

  alias Teiserver.Bridge.BridgeServer
  alias Teiserver.Telemetry
  alias Central.Config

  @impl Oban.Worker
  def perform(_) do
    if ConCache.get(:application_metadata_cache, "teiserver_startup_completed") == true do
      now = Timex.now() |> Timex.set([microsecond: 0])

      case Telemetry.get_server_minute_log(now) do
        nil ->
          perform_telemetry_persist(now)

        _ ->
          :ok
      end
    end
    :ok
  end

  defp perform_telemetry_persist(timestamp) do
    data = Telemetry.get_totals_and_reset()
      |> Map.drop([:cycle])

    if Application.get_env(:central, Teiserver)[:enable_discord_bridge] do
      if rem(Timex.now().minute(), 10) == 0 do
        if Config.get_site_config_cache("teiserver.Bridge player numbers") do
          bridge_pid = BridgeServer.get_bridge_pid()
          send(bridge_pid, {:update_stats, :client_count, Enum.count(data.client.total)})
          send(bridge_pid, {:update_stats, :player_count, Enum.count(data.client.player)})
          send(bridge_pid, {:update_stats, :match_count, data.battle.in_progress})
          send(bridge_pid, {:update_stats, :lobby_count, data.battle.lobby})
        end
      end
    end

    Telemetry.create_server_minute_log(%{
      timestamp: timestamp,
      data: data
    })
  end
end
