defmodule Teiserver.Battle.LobbyLib do
  @spec icon :: String.t()
  def icon, do: "far fa-sword"

  @spec colours :: {String.t(), String.t(), String.t()}
  def colours, do: Central.Helpers.StylingHelper.colours(:primary2)
end
