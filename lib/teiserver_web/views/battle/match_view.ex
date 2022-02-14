defmodule TeiserverWeb.Battle.MatchView do
  use TeiserverWeb, :view

  def view_colour(), do: Teiserver.Battle.MatchLib.colours()
  def icon(), do: Teiserver.Battle.MatchLib.icon()
end
