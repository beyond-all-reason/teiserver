defmodule Teiserver.Telemetry.ClientEventLib do
  use CentralWeb, :library

  # alias Teiserver.Telemetry.TelemetryMinuteLog

  @spec colours :: {String.t(), String.t(), String.t()}
  def colours(), do: Central.Helpers.StylingHelper.colours(:info2)

  @spec icon() :: String.t()
  def icon(), do: "far fa-sliders-up"
end
