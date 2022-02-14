defmodule Teiserver.Telemetry.TelemetryLib do
  @spec colours :: atom
  def colours(), do: :warning2

  @spec icon() :: String.t()
  def icon(), do: "far fa-monitor-heart-rate"
end
