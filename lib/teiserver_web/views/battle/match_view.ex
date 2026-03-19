defmodule TeiserverWeb.Battle.MatchView do
  use TeiserverWeb, :view

  alias Teiserver.Battle.MatchLib

  def view_colour(), do: MatchLib.colours()
  def icon(), do: MatchLib.icon()
end
