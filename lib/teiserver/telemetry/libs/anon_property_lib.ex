defmodule Teiserver.Telemetry.AnonPropertyLib do
  use CentralWeb, :library
  alias Teiserver.Telemetry.AnonProperty

  # Functions
  @spec icon :: String.t()
  def icon, do: "fa-regular fa-???"

  @spec colours :: atom
  def colours, do: :default
end
