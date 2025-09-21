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
      :tachyon_event_metrics,
      [
        distribution(
          [:tachyon, :request, :duration],
          event_name: [:tachyon, :request],
          measurement: :duration,
          reporter_options: [
            buckets: [1, 10, 50, 100, 150, 250, 500, 1_000]
          ],
          tags: [:command_id]
        ),
        counter(
          [:tachyon, :login, :ok],
          event_name: [:tachyon, :login, :ok],
          measurement: :count
        ),
        counter(
          [:tachyon, :login, :error],
          event_name: [:tachyon, :login, :error],
          measurement: :count,
          tags: [:reason]
        ),
        counter(
          [:tachyon, :disconnect],
          event_name: [:tachyon, :disconnect],
          measurement: :count,
          description: "normal logout with system/disconnect"
        ),
        counter(
          [:tachyon, :abrupt_disconnect],
          event_name: [:tachyon, :abrupt_disconnect],
          measurement: :count,
          description: "stopped connection without normal disconnect message"
        ),
        counter(
          [:tachyon, :request, :count],
          event_name: [:tachyon, :request],
          measurement: :count,
          tags: [:command_id, :code]
        ),
        counter(
          [:tachyon, :event, :count],
          event_name: [:tachyon, :event],
          measurement: :count,
          tags: [:command_id]
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
      :tachyon_player_polling_metrics,
      poll_rate,
      {__MODULE__, :execute_tachyon_player_metrics, []},
      [
        last_value(
          [:tachyon, :player, :count],
          event_name: @tachyon_player_metrics_event_name,
          description: "how many players are connected",
          measurement: :count
        ),
        last_value(
          [:tachyon, :party, :count],
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
