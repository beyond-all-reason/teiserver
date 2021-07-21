defmodule TeiserverWeb.Report.GeneralView do
  use TeiserverWeb, :view

  @spec colours :: {String.t(), String.t(), String.t()}
  def colours(), do: StylingHelper.colours(:primary)

  @spec icon() :: String.t()
  def icon(), do: StylingHelper.icon(:primary)

  @spec colours(String.t()) :: {String.t(), String.t(), String.t()}
  def colours("client_events"), do: Teiserver.Telemetry.ClientEventLib.colours()
  def colours("server_metrics"), do: Teiserver.Telemetry.TelemetryDayLogLib.colours()
end
