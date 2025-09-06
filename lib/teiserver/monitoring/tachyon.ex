defmodule Teiserver.Monitoring.Tachyon do
  @moduledoc """
  Anything related to tachyon metrics goes there
  """

  use PromEx.Plugin

  @tachyon_player_metrics_event_name [:prom_ex, :plugin, :tachyon, :player]
  @tachyon_party_metrics_event_name [:prom_ex, :plugin, :tachyon, :party]

  @impl true
  def event_metrics(_opts) do
    Event.build(
      :teiserver_tachyon_event_metrics,
      [
        # Telemetry.Metrics.summary(
        distribution(
          [:teiserver, :tachyon, :request, :duration],
          event_name: [:tachyon, :request],
          measurement: :duration,
          reporter_options: [
            buckets: [1, 10, 50, 100, 150, 250, 500, 1_000]
          ]
        )
      ]
    )
  end

  @impl true
  def polling_metrics(opts) do
    poll_rate = Keyword.get(opts, :poll_rate, 5_000)

    [
      tachyon_player_metrics(poll_rate)
    ]
  end

  defp tachyon_player_metrics(poll_rate) do
    Polling.build(
      :teiserver_tachyon_player_polling_metrics,
      poll_rate,
      {__MODULE__, :execute_tachyon_player_metrics, []},
      [
        last_value(
          [:teiserver, :tachyon, :player, :count],
          event_name: @tachyon_player_metrics_event_name,
          description: "how many players are connected",
          measurement: :count
        ),
        last_value(
          [:teiserver, :tachyon, :party, :count],
          event_name: @tachyon_party_metrics_event_name,
          description: "how many parties",
          measurement: :count
        )
      ]
    )
  end

  @doc false
  def execute_tachyon_player_metrics() do
    player_count = Teiserver.Player.connected_count()
    :telemetry.execute(@tachyon_player_metrics_event_name, %{count: player_count}, %{})

    party_count = Teiserver.Party.count()
    :telemetry.execute(@tachyon_party_metrics_event_name, %{count: party_count}, %{})
  end
end
