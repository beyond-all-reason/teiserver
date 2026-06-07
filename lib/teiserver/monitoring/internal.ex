defmodule Teiserver.Monitoring.Internal do
  @moduledoc false
  use PromEx.Plugin

  @impl PromEx.Plugin
  def event_metrics(_opts) do
    Event.build(
      :teiserver_internal_event_metrics,
      [
        distribution(
          [:teiserver, :moderation, :message_severity, :stop],
          event_name: [:moderation, :message_severity],
          measurement: :duration,
          reporter_options: [
            buckets: [
              1,
              2,
              3,
              5,
              8,
              13,
              21,
              34,
              55,
              89,
              144,
              233,
              377,
              610,
              987,
              1597,
              2584,
              4181
            ]
          ],
          tags: [:matched]
        ),
        counter(
          [:teiserver, :moderation, :message_severity, :stop],
          event_name: [:moderation, :message_severity],
          measurement: :count
        )
      ]
    )
  end

  @impl PromEx.Plugin
  def polling_metrics(_opts) do
    []
  end
end
