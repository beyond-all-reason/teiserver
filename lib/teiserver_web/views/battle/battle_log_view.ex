defmodule TeiserverWeb.Battle.MatchView do
  use TeiserverWeb, :view

  @spec colours() :: {String.t(), String.t(), String.t()}
  def colours, do: Teiserver.Battle.MatchLib.colours()

  @spec icon() :: String.t()
  def icon, do: Teiserver.Battle.MatchLib.icon()
end
