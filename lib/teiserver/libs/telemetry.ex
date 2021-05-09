defmodule Teiserver.Telemetry do
  import Telemetry.Metrics

  @spec metrics() :: List.t()
  def metrics() do
    [
      last_value("teiserver.client.count"),
      last_value("teiserver.battle.count"),
      # last_value("teiserver.ts.memory", unit: :byte),
      # last_value("teiserver.ts.message_queue_len"),
      # summary("teiserver.ts.call.stop.duration"),
      # counter("teiserver.ts.call.exception")
    ]
  end

  @spec periodic_measurements() :: List.t()
  def periodic_measurements() do
    [
      # {Teiserver.Telemetry, :measure_users, []},
      # {:process_info,
      #   event: [:teiserver, :ts],
      #   name: Teiserver.TelemetryServer,
      #   keys: [:message_queue_len, :memory]}
    ]
  end
end
