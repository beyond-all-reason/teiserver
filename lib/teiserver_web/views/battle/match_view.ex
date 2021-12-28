defmodule TeiserverWeb.Battle.MatchView do
  use TeiserverWeb, :view

  def colours(), do: Teiserver.Battle.MatchLib.colours()
  def icon(), do: Teiserver.Battle.MatchLib.icon()
end
