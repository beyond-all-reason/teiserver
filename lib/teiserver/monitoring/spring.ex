defmodule Teiserver.Monitoring.Spring do
  use PromEx.Plugin

  @impl true
  def event_metrics(_opts) do
    Event.build(
      :spring_metrics,
      Teiserver.Telemetry.metrics()
    )
  end
end
