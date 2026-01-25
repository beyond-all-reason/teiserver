defmodule Teiserver.Monitoring.Spring do
  use PromEx.Plugin

  @impl true
  def event_metrics(_opts) do
    Event.build(
      :spring_metrics,
      Teiserver.Telemetry.metrics()
    )
  end

  @impl true
  def polling_metrics(opts) do
    poll_rate = Keyword.get(opts, :poll_rate, 5_000)
    [spring_polling_metrics(poll_rate)]
  end

  defp spring_polling_metrics(poll_rate) do
    Polling.build(
      :teiserver_spring_player_polling_metrics,
      poll_rate,
      {__MODULE__, :execute_spring_polling_metrics, []},
      [
        last_value(
          [:teiserver, :spring, :login_queue_length],
          event_name: [:spring, :login_queue_length],
          description: "how many client sitting in the login queue",
          measurement: :value
        )
      ]
    )
  end

  def execute_spring_polling_metrics() do
    login_queue_length = Teiserver.Account.LoginThrottleServer.get_queue_length()
    :telemetry.execute([:spring, :login_queue_length], %{value: login_queue_length}, %{})
  end
end
