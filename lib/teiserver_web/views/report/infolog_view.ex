defmodule TeiserverWeb.Report.InfologView do
  use TeiserverWeb, :view

  @spec colours :: {String.t(), String.t(), String.t()}
  def colours(), do: Teiserver.Telemetry.InfologLib.colours()

  @spec icon() :: String.t()
  def icon(), do: Teiserver.Telemetry.InfologLib.icon()
end
