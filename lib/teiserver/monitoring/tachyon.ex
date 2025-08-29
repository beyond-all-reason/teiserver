defmodule Teiserver.Monitoring.Tachyon do
  @moduledoc """
  Anything related to tachyon metrics goes there
  """

  use PromEx.Plugin

  @tachyon_player_metrics_event_name [:prom_ex, :plugin, :tachyon, :player]

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
          description: "how many players are connected?",
          measurement: :count
        )
      ]
    )
  end

  @doc false
  def execute_tachyon_player_metrics() do
    count = Teiserver.Player.connected_count()

    :telemetry.execute(@tachyon_player_metrics_event_name, %{count: count}, %{})
  end
end
