defmodule TeiserverWeb.Battle.MatchView do
  alias Teiserver.Battle.MatchLib

  use TeiserverWeb, :view

  def view_colour(), do: MatchLib.colours()
  def icon(), do: MatchLib.icon()
end
