defmodule Teiserver.Telemetry.TelemetryLib do
  @spec colours :: atom
  def colours(), do: :warning2

  @spec icon() :: String.t()
  def icon(), do: "fa-regular fa-monitor-heart-rate"
end
