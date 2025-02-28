defmodule Teiserver.Logging.Tasks.PersistServerMinuteTask do
  use Oban.Worker, queue: :teiserver

  alias Teiserver.Bridge.BridgeServer
  alias Teiserver.{Telemetry, Logging}
  alias Teiserver.Config

  @impl Oban.Worker
  def perform(_) do
    if Teiserver.cache_get(:application_metadata_cache, "teiserver_full_startup_completed") ==
         true do
      now = Timex.now() |> Timex.set(microsecond: 0)

      case Logging.get_server_minute_log(now) do
        nil ->
          perform_telemetry_persist(now)

        _ ->
          :ok
      end
    end

    :ok
  end

  defp perform_telemetry_persist(timestamp) do
    data =
      Telemetry.get_totals_and_reset()
      |> Map.drop([:cycle])

    if Teiserver.Communication.use_discord?() do
      if rem(Timex.now().minute, 10) == 0 do
        if Config.get_site_config_cache("teiserver.Bridge player numbers") do
          [
            {:update_stats, :client_count, Enum.count(data.client.total)},
            {:update_stats, :player_count, Enum.count(data.client.player)},
            {:update_stats, :match_count, data.battle.in_progress},
            {:update_stats, :lobby_count, data.battle.lobby}
          ]
          |> Enum.each(&BridgeServer.send_bridge/1)
        end
      end
    end

    Logging.create_server_minute_log(%{
      timestamp: timestamp,
      data: data
    })
  end
end
