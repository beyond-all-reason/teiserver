defmodule Teiserver.Telemetry.TelemetryLib do
  @spec colours :: {String.t(), String.t(), String.t()}
  def colours(), do: Central.Helpers.StylingHelper.colours(:warning2)

  @spec icon() :: String.t()
  def icon(), do: "far fa-monitor-heart-rate"
end
