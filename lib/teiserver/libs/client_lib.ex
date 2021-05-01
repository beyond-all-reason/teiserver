defmodule Teiserver.ClientLib do
  # Functions
  @spec colours() :: {String.t(), String.t(), String.t()}
  def colours, do: Central.Helpers.StylingHelper.colours(:primary2)

  @spec icon() :: String.t()
  def icon, do: "fas fa-plug"
end
