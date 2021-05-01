defmodule Teiserver.BattleLib do
  # Functions
  @spec icon() :: String.t()
  def icon, do: "far fa-swords"

  @spec colours() :: {String.t(), String.t(), String.t()}
  def colours, do: Central.Helpers.StylingHelper.colours(:primary2)
end
