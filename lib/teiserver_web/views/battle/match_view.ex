defmodule BarserverWeb.Battle.MatchView do
  use BarserverWeb, :view

  def view_colour(), do: Barserver.Battle.MatchLib.colours()
  def icon(), do: Barserver.Battle.MatchLib.icon()
end
