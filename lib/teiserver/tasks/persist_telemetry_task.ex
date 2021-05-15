defmodule Teiserver.Tasks.PersistTelemetryTask do
  use Oban.Worker, queue: :teiserver

  alias Teiserver.Telemetry
  alias Teiserver.Telemetry.TelemetryServer

  @impl Oban.Worker
  def perform(_) do
    now = Timex.now() |> Timex.set([microsecond: 0])

    case Telemetry.get_telemetry_log(now) do
      nil ->
        perform_telemetry_persist(now)
        :ok

      _ ->
        # Log has already been added
        :ok
    end
  end

  defp perform_telemetry_persist(timestamp) do
    data = TelemetryServer.get_state()
      |> Map.drop([:cycle])

    Telemetry.create_telemetry_log(%{
      timestamp: timestamp,
      data: data
    })
  end
end
