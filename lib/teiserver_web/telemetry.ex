defmodule TeiserverWeb.Telemetry do
  @moduledoc false

  alias Teiserver.Telemetry, as: TeiserverTelemetry

  import Telemetry.Metrics

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.start.system_time",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.exception.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.socket_connected.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_join.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_handled_in.duration",
        tags: [:event],
        unit: {:native, :millisecond}
      ),

      # Database Time Metrics
      summary("Teiserver.Repo.query.total_time", unit: {:native, :millisecond}),
      summary("Teiserver.Repo.query.decode_time", unit: {:native, :millisecond}),
      summary("Teiserver.Repo.query.query_time", unit: {:native, :millisecond}),
      summary("Teiserver.Repo.query.queue_time", unit: {:native, :millisecond}),
      summary("Teiserver.Repo.query.idle_time", unit: {:native, :millisecond}),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io"),

      # Moderation
      distribution(
        [:moderation, :message_severity],
        event_name: [:teiserver, :moderation, :message_severity, :stop],
        measurement: :duration,
        reporter_options: [
          buckets: [1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610, 987, 1597, 2584, 4181]
        ],
        tags: [:matched]
      )
    ] ++
      TeiserverTelemetry.metrics()

    # Metrics end
  end
end
